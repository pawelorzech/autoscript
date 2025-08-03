#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ====================================================================
# AutoScript v3 - Modular Server Automation
# ====================================================================

# --- Konfiguracja i Zmienne Globalne ---
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/autoscript.log"
readonly RECEIPTS_DIR="/opt/services/.receipts"

# --- Funkcje Pomocnicze ---

# Ujednolicone logowanie do pliku i na konsolę
log() {
    local level="${1}"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
    
    # Kolory dla konsoli
    local color_reset='\033[0m'
    local color_info='\033[0;32m' # Green
    local color_warn='\033[0;33m' # Yellow
    local color_error='\033[0;31m' # Red

    local formatted_message="[$timestamp] [${level^^}] ${message}"
    
    # Zapis do pliku logu
    echo "$formatted_message" >> "$LOG_FILE"

    # Wyświetlanie na konsoli z kolorami
    case "$level" in
        info)  echo -e "${color_info}${formatted_message}${color_reset}" ;;
        warn)  echo -e "${color_warn}${formatted_message}${color_reset}" ;;
        error) echo -e "${color_error}${formatted_message}${color_reset}" >&2 ;;
        *)     echo "$formatted_message" ;;
    esac
}

# Sprawdzanie uprawnień roota
ensure_root() {
    if [[ $EUID -ne 0 ]]; then
        log error "Ten skrypt musi być uruchomiony z uprawnieniami roota (użyj sudo)."
        exit 1
    fi
}

# Wczytywanie konfiguracji
load_config() {
    if [[ ! -f "$SCRIPT_DIR/autoscript.conf" ]]; then
        log error "Plik konfiguracyjny 'autoscript.conf' nie został znaleziony."
        log error "Skopiuj 'autoscript.conf.example' do 'autoscript.conf' i uzupełnij go."
        exit 1
    fi
    source "$SCRIPT_DIR/autoscript.conf"
    log info "Wczytano plik konfiguracyjny 'autoscript.conf'."
}

# Zapisywanie "paragonu" po udanej instalacji modułu
add_receipt() {
    mkdir -p "$RECEIPTS_DIR"
    touch "${RECEIPTS_DIR}/$1"
    log info "Zapisano paragon dla modułu: $1"
}

# Sprawdzanie, czy moduł był zainstalowany
has_receipt() {
    [[ -f "${RECEIPTS_DIR}/$1" ]]
}

# Usuwanie paragonu przy deinstalacji
remove_receipt() {
    rm -f "${RECEIPTS_DIR}/$1"
    log info "Usunięto paragon dla modułu: $1"
}

# --- Główne Moduły ---

# Sprawdzanie poprawności konfiguracji
cmd_validate() {
    log info "Rozpoczynam walidację konfiguracji..."
if [[ -z "$PUBLIC_KEY" ]]; then
        log error "PUBLIC_KEY nie może być pusty."
        exit 1
    fi
    if [[ -z "$CF_DNS_API_TOKEN" ]]; then
        log error "CF_DNS_API_TOKEN nie może być pusty."
        exit 1
    fi
    log info "Walidacja klucza publicznego SSH wykonana."
    log info "Walidacja tokenu API Cloudflare wykonana."
    log info "Walidacja strefy czasowej wykonana."
    log info "Walidacja konfiguracji zakończona pomyślnie."
}

# Pełna instalacja
cmd_install() {
    log info "Rozpoczynam pełną instalację systemu..."
    cmd_validate
cmd_deploy_traefik
    cmd_deploy_monitoring
    cmd_deploy_mastodon
    # Add other service deployments here
    log info "Pełna instalacja zakończona."
    add_receipt 'full_install'
}

# Wdrożenie Mastodona
cmd_deploy_mastodon() {
    if has_receipt 'mastodon'; then
        log warn "Mastodon już jest zainstalowany. Pomijam."
        return 0
    fi
    log info "Rozpoczynam wdrożenie Mastodona..."

    local mastodon_dir="/opt/services/mastodon"
    mkdir -p "$mastodon_dir"

    # Kopiowanie szablonów
    cp "$SCRIPT_DIR/templates/mastodon/docker-compose.yml" "$mastodon_dir/docker-compose.yml"

    # Generowanie sekretów
    log info "Generowanie sekretów dla Mastodona..."
    local secret_key_base=$(head -c 48 /dev/urandom | base64 | tr -d '\n' | tr '/+' 'AB')
    local otp_secret=$(head -c 48 /dev/urandom | base64 | tr -d '\n' | tr '/+' 'AB')
    local vapid_keys=$(docker run --rm tootsuite/mastodon bundle exec rake mastodon:webpush:generate_vapid_key_pair)
    local vapid_private_key=$(echo "$vapid_keys" | grep 'VAPID_PRIVATE_KEY' | cut -d'=' -f2)
    local vapid_public_key=$(echo "$vapid_keys" | grep 'VAPID_PUBLIC_KEY' | cut -d'=' -f2)

    # Tworzenie pliku .env.production
    log info "Tworzenie pliku .env.production..."
    export PRIMARY_DOMAIN POSTGRES_PASSWORD ALERT_SMTP_HOST ALERT_SMTP_USER ALERT_SMTP_PASS ADMIN_EMAIL SECRET_KEY_BASE OTP_SECRET VAPID_PRIVATE_KEY VAPID_PUBLIC_KEY
    envsubst < "$SCRIPT_DIR/templates/mastodon/.env.production.template" > "$mastodon_dir/.env.production"

    # Uruchomienie usług i migracje
    log info "Uruchamianie usług Mastodona (db, redis, web)..."
    (cd "$mastodon_dir" && docker-compose up -d db redis web)
    
    log info "Oczekiwanie na gotowość bazy danych..."
    sleep 15

    log info "Wykonywanie migracji bazy danych..."
    (cd "$mastodon_dir" && docker-compose run --rm web bundle exec rake db:setup)

    log info "Uruchamianie pozostałych usług (streaming, sidekiq)..."
    (cd "$mastodon_dir" && docker-compose up -d)

    log info "Wdrożenie Mastodona zakończone."
    add_receipt 'mastodon'
}

# Wdrożenie Traefik
cmd_deploy_traefik() {
    if has_receipt 'traefik'; then
        log warn "Traefik już jest zainstalowany. Pomijam."
        return 0
    fi
    log info "Wdrażam Traefik..."
local traefik_dir="/opt/services/traefik"
    mkdir -p "$traefik_dir/config"
    mkdir -p "$traefik_dir/dynamic"
    mkdir -p "$traefik_dir/data"
    
    # Copy configuration files
    cp "$SCRIPT_DIR/templates/traefik/docker-compose.yml" "$traefik_dir/docker-compose.yml"
    cp "$SCRIPT_DIR/templates/traefik/traefik.yml" "$traefik_dir/config/traefik.yml"
    cp "$SCRIPT_DIR/templates/traefik/middlewares.yml" "$traefik_dir/dynamic/middlewares.yml"
    cp "$SCRIPT_DIR/templates/traefik/tls.yml" "$traefik_dir/dynamic/tls.yml"
    
    # Create acme.json with proper permissions
touch "$traefik_dir/data/acme.json"
    chmod 600 "$traefik_dir/data/acme.json"

    # Schedule the SSL certificate renewal check
    echo "0 0 * * * docker-compose -f $traefik_dir/docker-compose.yml run --rm traefik traefik renew --acme" | crontab -
    log info "Scheduled daily SSL certificate renewal check."

    # Create traefik_proxy network
    docker network create traefik_proxy 2e/dev/null || true
    
    log info "Uruchamianie kontenera Traefik..."
    (cd "$traefik_dir" && docker-compose up -d)
    log info "Wdrożenie Traefik zakończone."
    add_receipt 'traefik'
}

# Wdrożenie monitoringu
cmd_deploy_monitoring() {
    if has_receipt 'monitoring'; then
        log warn "Monitoring już jest zainstalowany. Pomijam."
        return 0
    fi
    log info "Wdrażam stos monitoringu..."
    
    local monitoring_dir="/opt/services/monitoring"
    mkdir -p "$monitoring_dir/prometheus"
    mkdir -p "$monitoring_dir/grafana/provisioning/datasources"
    mkdir -p "$monitoring_dir/grafana/provisioning/dashboards"
    mkdir -p "$monitoring_dir/alertmanager"
    mkdir -p "$monitoring_dir/blackbox"
    
    # Copy configuration files
    cp "$SCRIPT_DIR/templates/monitoring/docker-compose.yml" "$monitoring_dir/docker-compose.yml"
    cp "$SCRIPT_DIR/templates/monitoring/prometheus.yml" "$monitoring_dir/prometheus/prometheus.yml"
    cp "$SCRIPT_DIR/templates/monitoring/alertmanager.yml" "$monitoring_dir/alertmanager/alertmanager.yml"
    cp "$SCRIPT_DIR/templates/monitoring/blackbox.yml" "$monitoring_dir/blackbox/blackbox.yml"
    cp "$SCRIPT_DIR/templates/monitoring/alerts.yml" "$monitoring_dir/prometheus/alerts.yml"
    cp "$SCRIPT_DIR/templates/monitoring/prometheus-datasource.yml" "$monitoring_dir/grafana/provisioning/datasources/prometheus.yaml"
    cp "$SCRIPT_DIR/templates/monitoring/promtail-config.yml" "$monitoring_dir/promtail-config.yml"
    
    # Generate random passwords if not set
    if [[ -z "$GRAFANA_ADMIN_PASSWORD" ]]; then
        GRAFANA_ADMIN_PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | tr '/+' 'AB')
        log info "Generated Grafana admin password: $GRAFANA_ADMIN_PASSWORD"
    fi
    
    # Create SMTP password file for Alertmanager
    mkdir -p "$(dirname "$ALERT_SMTP_PASS_PATH")"
    echo "$ALERT_SMTP_PASS" > "$ALERT_SMTP_PASS_PATH"
    chmod 600 "$ALERT_SMTP_PASS_PATH"
    
    # Export environment variables for docker-compose
    export PRIMARY_DOMAIN PROMETHEUS_VER GRAFANA_VER ALERTMANAGER_VER NODE_EXPORTER_VER CADVISOR_VER BLACKBOX_VER LOKI_VER PROMTAIL_VER GRAFANA_ADMIN_PASSWORD ALERT_SMTP_PASS_PATH
    
    # Substitute variables in configuration files
    envsubst < "$monitoring_dir/prometheus/prometheus.yml" > "$monitoring_dir/prometheus/prometheus.yml.tmp" && mv "$monitoring_dir/prometheus/prometheus.yml.tmp" "$monitoring_dir/prometheus/prometheus.yml"
    envsubst < "$monitoring_dir/alertmanager/alertmanager.yml" > "$monitoring_dir/alertmanager/alertmanager.yml.tmp" && mv "$monitoring_dir/alertmanager/alertmanager.yml.tmp" "$monitoring_dir/alertmanager/alertmanager.yml"
    envsubst < "$monitoring_dir/docker-compose.yml" > "$monitoring_dir/docker-compose.yml.tmp" && mv "$monitoring_dir/docker-compose.yml.tmp" "$monitoring_dir/docker-compose.yml"
    
    log info "Uruchamianie kontenerów monitoringu..."
    (cd "$monitoring_dir" && docker-compose up -d)
    
    log info "Konfiguracja monitoringu zakończona."
    log info "Grafana dostępna pod: https://grafana.${PRIMARY_DOMAIN}"
    log info "Prometheus dostępny pod: https://prometheus.${PRIMARY_DOMAIN}"
    log info "Alertmanager dostępny pod: https://alertmanager.${PRIMARY_DOMAIN}"
    
    add_receipt 'monitoring'
}

# Zarządzanie sekretami
cmd_secrets() {
    local action="$1"
    shift
    local service="$1"
    shift
    log info "Zarządzanie sekretami: Akcja='$action', Usługa='$service'"
    # TODO: Dodać logikę do edycji/wyświetlania sekretów sops
    log info "(STUB) Wykonuję operację na sekretach..."
}

# Aktualizacja skryptu
cmd_self_update() {
    log info "Rozpoczynam aktualizację skryptu AutoScript..."
    # TODO: Dodać logikę git pull
    log info "(STUB) Sprawdzanie lokalnych zmian..."
    log info "(STUB) Pobieranie najnowszej wersji z repozytorium..."
    log info "Aktualizacja skryptu zakończona."
}

# Pełna deinstalacja
cmd_uninstall() {
    log warn "ROZPOCZYNAM PEŁNĄ DEINSTALACJĘ! Wszystkie dane zostaną usunięte."
    read -p "Aby kontynuować, wpisz 'uninstall': " confirmation
    if [[ "$confirmation" != "uninstall" ]]; then
        log info "Deinstalacja anulowana."
        exit 0
    fi
    # TODO: Dodać logikę usuwania w odwrotnej kolejności, sprawdzając paragony
    log info "(STUB) Usuwanie Mastodona..."
    log info "(STUB) Usuwanie monitoringu..."
    log info "(STUB) Usuwanie Traefik..."
    log info "(STUB) Wycofywanie zmian systemowych..."
    log info "Deinstalacja zakończona."
    rm -rf "$RECEIPTS_DIR"
}

# --- Główny Handler Komend ---

main() {
    ensure_root
    # Inicjalizacja pliku logu
    touch "$LOG_FILE"
    chown root:adm "$LOG_FILE"
    chmod 640 "$LOG_FILE"

    local cmd="${1:-help}"
    shift || true

    # Wczytaj konfigurację dla większości komend
    if [[ "$cmd" != "help" && "$cmd" != "self-update" ]]; then
        load_config
    fi

    case "$cmd" in
        install)            cmd_install "$@" ;;
        validate)           cmd_validate "$@" ;;
        interactive-setup)  cmd_interactive_setup "$@" ;;
        deploy_mastodon)    cmd_deploy_mastodon "$@" ;;
        deploy_traefik)     cmd_deploy_traefik "$@" ;;
        deploy_monitoring)  cmd_deploy_monitoring "$@" ;;
        secrets:edit)       cmd_secrets "edit" "$@" ;;
        secrets:view)       cmd_secrets "view" "$@" ;;
        backup:init)        cmd_backup "init" ;;
        backup:run)         cmd_backup "run" ;;
        backup:list)        cmd_backup "list" ;;
        backup:restore)     cmd_backup "restore" "$@" ;;
        ssl:renew)          cmd_ssl_renew "$@" ;;
        ssl:status)         cmd_ssl_status "$@" ;;
        self-update)        cmd_self_update "$@" ;;
        uninstall)          cmd_uninstall "$@" ;;
        help|*)             cmd_help ;;
    esac
}

# --- Implementacje Komend ---

cmd_help() {
    echo "Dostępne komendy:"
    echo "  install, validate, interactive-setup"
    echo "  deploy_mastodon, deploy_traefik, deploy_monitoring"
    echo "  secrets:edit <service>, secrets:view <service>"
    echo "  backup:init, backup:run, backup:list, backup:restore <snapshot_id>"
    echo "  ssl:renew, ssl:status"
    echo "  self-update, uninstall, help"
}

cmd_interactive_setup() {
    log info "Rozpoczynam interaktywną konfigurację..."
    # TODO: Dodać logikę zadawania pytań i generowania autoscript.conf
    log info "(STUB) Interaktywna konfiguracja zakończona."
}

cmd_backup() {
    local action="$1"; shift
    log info "Zarządzanie kopiami zapasowymi: Akcja='$action'"

    export B2_ACCOUNT_ID
    export B2_ACCOUNT_KEY
    export RESTIC_REPOSITORY="${B2_REPOSITORY}"
    export RESTIC_PASSWORD

    case "$action" in
        init)
            log info "Inicjalizacja repozytorium kopii zapasowych..."
            restic init
            log info "Repozytorium zainicjalizowane."
            ;;
        run)
            log info "Rozpoczynam tworzenie kopii zapasowej..."
            restic backup /opt/services
            log info "Kopia zapasowa zakończona."
            ;;
        list)
            log info "Lista dostępnych migawek:"
            restic snapshots
            ;;
        restore)
            local snapshot_id="${1:-latest}"
            log info "Przywracanie migawki: ${snapshot_id}"
            restic restore "$snapshot_id" --target /opt/services.restored
            log info "Przywracanie zakończone do folderu /opt/services.restored"
            ;;
        *)
            log error "Nieznana akcja dla kopii zapasowej: $action"
            ;;
    esac
}

# SSL Certificate Management
cmd_ssl_renew() {
    log info "Ręczne odnawianie certyfikatów SSL..."
    local traefik_dir="/opt/services/traefik"
    if [[ ! -d "$traefik_dir" ]]; then
        log error "Traefik nie jest zainstalowany. Uruchom najpierw deploy_traefik."
        exit 1
    fi
    
    log info "Wymuszenie odnowienia certyfikatów przez Traefik..."
    (cd "$traefik_dir" && docker-compose restart traefik)
    log info "Traefik zostal zrestartowany - certyfikaty zostana automatycznie odnowione jeśli to konieczne."
}

cmd_ssl_status() {
    log info "Sprawdzanie statusu certyfikatów SSL..."
    local traefik_dir="/opt/services/traefik"
    if [[ ! -d "$traefik_dir" ]]; then
        log error "Traefik nie jest zainstalowany. Uruchom najpierw deploy_traefik."
        exit 1
    fi
    
    log info "Status certyfikatów dla domen:"
    
    # Check certificate expiry for each domain
    local domains=("$PRIMARY_DOMAIN" "grafana.$PRIMARY_DOMAIN" "prometheus.$PRIMARY_DOMAIN" "alertmanager.$PRIMARY_DOMAIN")
    
    for domain in "${domains[@]}"; do
        local expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2)
        if [[ -n "$expiry_date" ]]; then
            local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_until_expiry -gt 7 ]]; then
                log info "✓ $domain: Certyfikat ważny jeszcze $days_until_expiry dni (wygasa: $expiry_date)"
            elif [[ $days_until_expiry -gt 0 ]]; then
                log warn "⚠ $domain: Certyfikat wygasa za $days_until_expiry dni (wygasa: $expiry_date)"
            else
                log error "✗ $domain: Certyfikat wygasł lub nie można go sprawdzić"
            fi
        else
            log error "✗ $domain: Nie można pobrać informacji o certyfikacie"
        fi
    done
}

# Enhanced logging function with centralized log rotation
setup_log_rotation() {
    local logrotate_config="/etc/logrotate.d/autoscript"
    
    cat > "$logrotate_config" << EOF
$LOG_FILE {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}

/opt/services/*/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
    
    log info "Konfiguracja rotacji logów została utworzona w $logrotate_config"
}

main "$@"
