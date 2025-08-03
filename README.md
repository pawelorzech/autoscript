<p align="center">
  <a href="#">
    <img src="https://img.shields.io/badge/AutoScript-v4.0-blue.svg" alt="AutoScript Version">
  </a>
  <a href="#6-licencja">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/platform-Debian%2FUbuntu-orange.svg" alt="Platform">
  </a>
</p>

<h1 align="center">AutoScript: Zautomatyzowana Platforma Mastodon</h1>

**AutoScript to w pełni zautomatyzowane, bezpieczne i gotowe do użycia rozwiązanie do wdrażania i zarządzania serwerem Mastodon oraz jego kompletnym środowiskiem.** Zapomnij o ręcznej konfiguracji – ten projekt przekształca "surowy" serwer w gotową do pracy, zabezpieczoną i monitorowaną platformę za pomocą kilku prostych komend.

---

## Spis Treści

1.  [Filozofia Projektu](#1-filozofia-projektu)
2.  [Kluczowe Funkcje](#2-kluczowe-funkcje)
3.  [Architektura w Pigułce](#3-architektura-w-pigułce)
4.  [Instalacja (Szybki Start)](#4-instalacja-szybki-start)
5.  [Przewodnik po Komendach](#5-przewodnik-po-komendach)
6.  [Licencja](#6-licencja)

---

## 1. Filozofia Projektu

- **Automatyzacja ponad wszystko**: Od instalacji pakietów, przez hardening systemu, po wdrożenie Mastodona – wszystko jest zautomatyzowane.
- **Bezpieczeństwo Domyślnie (Secure by Default)**: Wdrażamy najlepsze praktyki bezpieczeństwa od samego początku, nie jako opcję.
- **Idempotentność i Niezawodność**: Skrypt można bezpiecznie uruchamiać wielokrotnie. Zawsze doprowadzi system do pożądanego stanu.

## 2. Kluczowe Funkcje

- **Automatyczne Wdrożenie Mastodona**: Pełna instalacja i konfiguracja Mastodona, włącznie z bazą danych i Redis.
- **Hardening Systemu**: Wzmacnianie zabezpieczeń SSH, firewall UFW, `CrowdSec` i `Fail2ban`.
- **Zintegrowany Monitoring i Logowanie**: Pełny stos monitoringu (Prometheus, Grafana) i logów (Loki, Promtail) z automatycznym odkrywaniem usług.
- **Automatyczne Certyfikaty SSL**: Integracja Traefika z Let's Encrypt i Cloudflare.
- **Bezpieczne Zarządzanie Sekretami**: Szyfrowanie wszystkich wrażliwych danych za pomocą `sops`.
- **Walidacja Konfiguracji**: Sprawdzanie poprawności ustawień przed wprowadzeniem zmian w systemie.

## 3. Architektura w Pigułce

- **Modularność**: Każdą operację wykonuje się dedykowaną komendą (np. `./start.sh deploy_traefik`).
- **Idempotentność**: Skrypt śledzi ukończone instalacje. Można go bezpiecznie uruchamiać wielokrotnie.
- **Walidacja "Pre-flight"**: Komenda `validate` sprawdza poprawność konfiguracji *przed* dokonaniem jakichkolwiek zmian.

## 4. Instalacja (Szybki Start)

1.  **Zaloguj się jako `root` na nowym serwerze (Debian/Ubuntu).**
2.  **Zainstaluj `git` i sklonuj repozytorium:**
    ```bash
    apt update && apt install -y git
    git clone https://github.com/pawelorzech/autoscript.git && cd autoscript
    ```
3.  **Skonfiguruj AutoScript:**
    ```bash
    cp autoscript.conf.example autoscript.conf
    nano autoscript.conf # Wypełnij wszystkie zmienne
    ```
4.  **Sprawdź poprawność konfiguracji:**
    ```bash
    sudo ./start.sh validate
    ```
5.  **Uruchom pełną instalację:**
    ```bash
    sudo ./start.sh install
    ```

## 5. Przewodnik po Komendach

| Komenda                 | Opis                                                                                   |
| ----------------------- | -------------------------------------------------------------------------------------- |
| `install`               | **Główna instalacja.** Uruchamia walidację i wdraża wszystkie podstawowe moduły.         |
| `validate`              | Sprawdza poprawność pliku `autoscript.conf` i połączeń z zewnętrznymi API.             |
| `deploy_mastodon`       | Wdraża i konfiguruje aplikację Mastodon.                                               |
| `deploy_traefik`        | Wdraża i konfiguruje reverse proxy Traefik.                                            |
| `deploy_monitoring`     | Wdraża stos monitoringu (Prometheus, Grafana, Alertmanager).                           |
| `secrets:edit <nazwa>`  | Otwiera zaszyfrowany plik z sekretami dla danej usługi w edytorze.                      |
| `secrets:view <nazwa>`  | Wyświetla odszyfrowaną zawartość pliku z sekretami.                                     |
| `self-update`           | Aktualizuje skrypt AutoScript do najnowszej wersji z repozytorium Git.                   |
| `uninstall`             | **Niebezpieczne!** Usuwa wszystkie komponenty, dane i konfiguracje stworzone przez skrypt. |

## 6. Licencja

Projekt jest udostępniany na licencji MIT.
