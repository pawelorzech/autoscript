<p align="center">
  <a href="#">
    <img src="https://img.shields.io/badge/AutoScript-v4.1-blue.svg" alt="AutoScript Version">
  </a>
  <a href="#8-licencja">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  </a>
  <a href="#">
    <img src="https://img.shields.io/badge/platform-Debian%2FUbuntu-orange.svg" alt="Platform">
  </a>
</p>

<h1 align="center">AutoScript: Zautomatyzowana Platforma Serwerowa</h1>

**AutoScript to w pełni zautomatyzowane, bezpieczne i gotowe do użycia rozwiązanie do wdrażania i zarządzania kompletnym środowiskiem serwerowym.** Projekt ten przekształca "surowy" serwer w gotową do pracy, zabezpieczoną i monitorowaną platformę, na której główną, przykładową aplikacją jest **Mastodon**.

---

## Spis Treści

1.  [Architektura Platformy: Co zostanie zainstalowane?](#1-architektura-platformy-co-zostanie-zainstalowane)
2.  [Przewodnik Konfiguracyjny: Zdobywanie Kluczy](#2-przewodnik-konfiguracyjny-zdobywanie-kluczy)
3.  [Instalacja (Szybki Start)](#3-instalacja-szybki-start)
4.  [Przewodnik po Komendach](#4-przewodnik-po-komendach)
5.  [Aspekty Bezpieczeństwa](#5-aspekty-bezpieczeństwa)
6.  [Licencja](#6-licencja)

---

## 1. Architektura Platformy: Co zostanie zainstalowane?

AutoScript buduje wielowarstwową, nowoczesną platformę serwerową. Oto komponenty, które zostaną wdrożone i skonfigurowane:

| Warstwa             | Komponent                               | Rola w Systemie                                                                                             |
| ------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Aplikacja**       | **Mastodon**                            | Główna aplikacja platformy – zdecentralizowana sieć społecznościowa.                                        |
| **Baza Danych**     | **PostgreSQL**                          | Niezawodna, obiektowo-relacyjna baza danych, wymagana przez Mastodona.                                      |
| **Proxy i SSL**     | **Traefik**                             | Nowoczesny reverse proxy, który automatycznie zarządza ruchem i certyfikatami SSL od Let's Encrypt.         |
| **Konteneryzacja**  | **Docker**                              | Platforma do uruchamiania wszystkich aplikacji w izolowanych, bezpiecznych kontenerach.                       |
| **Monitoring**      | **Prometheus**                          | System do zbierania metryk wydajnościowych ze wszystkich komponentów platformy.                               |
|                     | **Grafana**                             | Narzędzie do wizualizacji metryk zebranych przez Prometheus w formie pięknych i czytelnych dashboardów.       |
|                     | **Alertmanager**                        | System do wysyłania powiadomień (e-mail) w razie wykrycia problemów (np. wysokiego użycia CPU).             |
| **Logowanie**       | **Loki & Promtail**                     | System do centralnego zbierania i przeszukiwania logów ze wszystkich aplikacji i z samego systemu operacyjnego. |
| **Bezpieczeństwo**  | **UFW, Hardened SSH, CrowdSec, Fail2ban** | Wielowarstwowy system zabezpieczeń: firewall, wzmocnione SSH, proaktywna ochrona przed włamaniami.          |

## 2. Przewodnik Konfiguracyjny: Zdobywanie Kluczy

Plik `autoscript.conf` wymaga podania dwóch kluczowych informacji. Oto jak je zdobyć:

### Klucz Publiczny SSH (`PUBLIC_KEY`)

Klucz SSH służy do bezpiecznego logowania na serwer bez hasła. Skrypt zablokuje logowanie hasłem, więc ten krok jest **niezbędny**.

**1. Sprawdź, czy masz już klucz:**

```bash
ls ~/.ssh/id_ed25519.pub
```

Jeśli plik istnieje, przejdź do kroku 2. Jeśli nie, **wygeneruj nowy klucz**, wpisując w terminalu na **swoim lokalnym komputerze**:

```bash
ssh-keygen -t ed25519 -C "twoj_email@example.com"
```

Naciśnij Enter, aby zaakceptować domyślną lokalizację zapisu. Możesz opcjonalnie podać hasło do klucza dla dodatkowego bezpieczeństwa.

**2. Wyświetl i skopiuj klucz publiczny:**

```bash
cat ~/.ssh/id_ed25519.pub
```

Skopiuj **całą wyświetloną linię** (zaczynającą się od `ssh-ed25519 ...`) i wklej ją jako wartość zmiennej `PUBLIC_KEY` w pliku `autoscript.conf`.

### Token API Cloudflare (`CF_DNS_API_TOKEN`)

Ten token pozwala Traefikowi na automatyczne potwierdzenie, że jesteś właścicielem domeny, co jest niezbędne do generowania certyfikatów SSL.

1.  **Zaloguj się** na swoje konto [Cloudflare](https://dash.cloudflare.com).
2.  Przejdź do sekcji **"My Profile"** (w prawym górnym rogu) > **"API Tokens"**.
    - *Bezpośredni link:* [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
3.  Kliknij przycisk **"Create Token"**.
4.  Znajdź szablon **"Edit zone DNS"** i kliknij **"Use template"**.
5.  Skonfiguruj token:
    - **Permissions**: Upewnij się, że jest `Zone:DNS:Edit`.
    - **Zone Resources**: Wybierz `Include` > `Specific zone` > i wybierz z listy swoją domenę (`social.ovh` w domyślnej konfiguracji).
6.  Kliknij **"Continue to summary"**, a następnie **"Create Token"**.
7.  **Skopiuj wygenerowany token.** To jedyny moment, kiedy jest on w pełni widoczny. Wklej go jako wartość zmiennej `CF_DNS_API_TOKEN` w pliku `autoscript.conf`.

## 3. Instalacja (Szybki Start)

1.  **Zaloguj się jako `root` na nowym serwerze (Debian/Ubuntu).**
2.  **Zainstaluj `git` i sklonuj repozytorium:**
    ```bash
    apt update && apt install -y git
    git clone https://github.com/pawelorzech/autoscript.git && cd autoscript
    ```
3.  **Skonfiguruj AutoScript:**
    ```bash
    cp autoscript.conf.example autoscript.conf
    nano autoscript.conf # Wypełnij zmienne zgodnie z przewodnikiem powyżej
    ```
4.  **Sprawdź poprawność konfiguracji:**
    ```bash
    sudo ./start.sh validate
    ```
5.  **Uruchom pełną instalację:**
    ```bash
    sudo ./start.sh install
    ```

## 4. Przewodnik po Komendach

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

## 5. Aspekty Bezpieczeństwa

AutoScript traktuje bezpieczeństwo jako fundamentalny element.

- **Hardening Systemu**: Skrypt automatycznie zmienia domyślny port SSH, blokuje logowanie na konto `root`, wyłącza logowanie hasłem (wymuszając użycie kluczy SSH) i konfiguruje uwierzytelnianie dwuetapowe (TOTP) dla komendy `sudo`.
- **Firewall (UFW)**: Konfigurowana jest zapora sieciowa, która domyślnie blokuje cały ruch przychodzący, otwierając tylko niezbędne porty.
- **Ochrona przed Włamaniami**: Instalowany jest `CrowdSec` (nowoczesny, oparty na reputacji IPS) oraz `Fail2ban` (klasyczna ochrona logów).
- **Bezpieczeństwo Kontenerów**: Docker jest konfigurowany z `userns-remap`, co znacząco ogranicza potencjalne szkody w razie "ucieczki" z kontenera.

## 6. Licencja

Projekt jest udostępniany na licencji MIT.