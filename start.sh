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
    # TODO: Dodać logikę walidacji (format klucza, połączenie z Cloudflare itp.)
    log info "(STUB) Walidacja klucza publicznego SSH..."
    log info "(STUB) Walidacja tokenu API Cloudflare..."
    log info "(STUB) Walidacja strefy czasowej..."
    log info "Walidacja konfiguracji zakończona pomyślnie."
}

# Pełna instalacja
cmd_install() {
    log info "Rozpoczynam pełną instalację systemu..."
    cmd_validate
    # TODO: Dodać wywołania poszczególnych modułów instalacyjnych
    log info "(STUB) Instalacja podstawowych narzędzi..."
    log info "(STUB) Konfiguracja zabezpieczeń systemowych..."
    cmd_deploy_traefik
    cmd_deploy_monitoring
    # ... i tak dalej
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
    # TODO: Dodać logikę z poprzedniej wersji skryptu
    log info "(STUB) Tworzenie folderów i plików konfiguracyjnych..."
    log info "(STUB) Uruchamianie kontenera Traefik..."
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
    # TODO: Dodać logikę z poprzedniej wersji skryptu
    log info "(STUB) Konfiguracja Prometheus, Grafana, Alertmanager..."
    log info "(STUB) Uruchamianie kontenerów monitoringu..."
    log info "Wdrożenie monitoringu zakończone."
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
        backup:run)         cmd_backup "run" ;;
        backup:restore)     cmd_backup "restore" "$@" ;;
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
    echo "  backup:run, backup:restore <snapshot_id>"
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
    # TODO: Dodać logikę restic
    log info "(STUB) Wykonuję operację na kopiach zapasowych..."
}

# ... (reszta funkcji)

main "$@"