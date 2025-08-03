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
    log info "Rozpoczynam wdrożenie Mastodona..."
    # TODO: Dodać logikę (klonowanie repo, generowanie .env, migracje)
    log info "(STUB) Klonowanie repozytorium Mastodona..."
    log info "(STUB) Generowanie pliku .env.production..."
    log info "(STUB) Uruchamianie kontenerów Mastodona..."
    log info "(STUB) Wykonywanie migracji bazy danych..."
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
        deploy_mastodon)    cmd_deploy_mastodon "$@" ;;
        deploy_traefik)     cmd_deploy_traefik "$@" ;;
        deploy_monitoring)  cmd_deploy_monitoring "$@" ;;
        secrets:edit)       cmd_secrets "edit" "$@" ;;
        secrets:view)       cmd_secrets "view" "$@" ;;
        self-update)        cmd_self_update "$@" ;;
        uninstall)          cmd_uninstall "$@" ;;
        help|*)             # TODO: Dodać funkcję wyświetlającą pomoc
                            log info "Dostępne komendy: install, validate, deploy_mastodon, uninstall, ..." ;;
    esac
}

main "$@"