# AutoScript - Zautomatyzowana Konfiguracja Serwera

## 1. Przegląd

Ten projekt zawiera kompleksowy skrypt `start.sh`, który automatyzuje proces konfiguracji i zabezpieczania nowego serwera opartego na systemie Debian (lub jego pochodnych, jak Ubuntu). Skrypt instaluje niezbędne oprogramowanie, wzmacnia zabezpieczenia systemu (hardening) i wdraża środowisko aplikacyjne oparte na kontenerach Docker.

Jest to idealne rozwiązanie do szybkiego przygotowania serwera deweloperskiego lub produkcyjnego, z gotowym do użycia reverse proxy (Traefik) oraz pełnym stosem monitoringu (Prometheus, Grafana).

## 2. Główne Funkcje

- **Automatyzacja:** Uruchom jeden skrypt, aby w pełni przygotować serwer.
- **Zabezpieczenia (Hardening):**
  - Konfiguracja firewalla `UFW`.
  - Wzmocnienie zabezpieczeń SSH (zmiana portu, blokada logowania roota, autoryzacja kluczem).
  - Tworzenie dedykowanego użytkownika `admin` z uprawnieniami `sudo` i weryfikacją dwuetapową (TOTP).
  - Instalacja i konfiguracja `CrowdSec` (system zapobiegania włamaniom).
  - Wdrożenie podstawowych zabezpieczeń jądra systemu.
- **Środowisko Docker:**
  - Instalacja i konfiguracja Docker Engine z najlepszymi praktykami (m.in. `userns-remap`).
  - Wdrożenie `Traefik` jako reverse proxy z automatycznym generowaniem certyfikatów SSL/TLS od Let's Encrypt (przy użyciu Cloudflare DNS).
- **Monitoring i Alerty:**
  - Wdrożenie `Prometheus` do zbierania metryk.
  - Wdrożenie `Grafana` do wizualizacji danych z gotową konfiguracją.
  - Wdrożenie `Alertmanager` do wysyłania powiadomień o anomaliach (e-mailem).
  - Wdrożenie eksporterów metryk (`node-exporter`, `cAdvisor`, `blackbox-exporter`).
- **Zarządzanie Sekretami:**
  - Bezpieczne zarządzanie hasłami i kluczami API przy użyciu `sops` i `age`, bez przechowywania ich w formie jawnego tekstu.

## 3. Wymagania Wstępne

Zanim uruchomisz skrypt, upewnij się, że posiadasz:

1.  **Nowy serwer** z systemem operacyjnym Debian lub Ubuntu.
2.  **Dostęp do konta `root`** na tym serwerze.
3.  **Domenę internetową** zarządzaną przez **Cloudflare**.
4.  **Klucz API Cloudflare** z uprawnieniami do edycji strefy DNS (`DNS:Edit`). Możesz go wygenerować w panelu Cloudflare: `My Profile > API Tokens > Create Token`.
5.  **Publiczny klucz SSH** (np. zawartość pliku `~/.ssh/id_ed25519.pub`), który zostanie użyty do autoryzacji nowego użytkownika `admin`.

## 4. Konfiguracja

Skrypt jest konfigurowany za pomocą zmiennych środowiskowych.

### Zmienne Wymagane

Musisz ustawić te zmienne przed uruchomieniem skryptu:

- `PUBLIC_KEY`: Twój publiczny klucz SSH.
  ```bash
  # Przykład
  export PUBLIC_KEY='ssh-ed25519 AAAA... twoja_nazwa@twoj_komputer'
  ```
- `CF_DNS_API_TOKEN`: Twój token API od Cloudflare.
  ```bash
  # Przykład
  export CF_DNS_API_TOKEN='AbCdEfGhIjKlMnOpQrStUvWxYz1234567890'
  ```

### Zmienne Opcjonalne

Możesz dostosować działanie skryptu, ustawiając poniższe zmienne (mają one wartości domyślne):

- `PRIMARY_DOMAIN`: Twoja główna domena (np. `mojadomena.com`). Domyślnie: `orzech.me`.
- `ADMIN_EMAIL`: Adres e-mail do powiadomień (np. od Let's Encrypt, Alertmanager). Domyślnie: `admin@orzech.me`.
- `TIMEZONE`: Strefa czasowa serwera. Domyślnie: `Europe/Warsaw`.
- `ALERT_SMTP_...`: Zmienne do konfiguracji serwera SMTP do wysyłania alertów.
- `*_VER`: Wersje obrazów Docker (np. `TRAEFIK_VER`). Pozwala na przypięcie konkretnych wersji oprogramowania.

## 5. Użycie

1.  Sklonuj to repozytorium na swój lokalny komputer lub bezpośrednio na serwer.
2.  Przejdź do folderu projektu: `cd autoscript`.
3.  Ustaw **wymagane** zmienne środowiskowe (patrz punkt 4).
    ```bash
    export PUBLIC_KEY='...'
    export CF_DNS_API_TOKEN='...'
    ```
4.  Opcjonalnie ustaw inne zmienne, aby nadpisać wartości domyślne.
    ```bash
    export PRIMARY_DOMAIN='twojadomena.pl'
    export ADMIN_EMAIL='admin@twojadomena.pl'
    ```
5.  Uruchom skrypt z uprawnieniami `root`.
    ```bash
    sudo ./start.sh
    ```
6.  Skrypt wykona wszystkie kroki automatycznie. Proces może potrwać kilka minut.

## 6. Co robić po zakończeniu skryptu?

Po pomyślnym wykonaniu skryptu, twoje środowisko jest gotowe, ale musisz wiedzieć o kilku ważnych zmianach:

1.  **Nowy Port SSH:** Port SSH został zmieniony na losowy numer z zakresu 10000-65535. **Znajdziesz go w pliku `/root/ssh_port.txt`**.
    ```bash
    # Zaloguj się na serwerze jako root i wykonaj:
    cat /root/ssh_port.txt
    ```
2.  **Logowanie na serwer:**
    - Logowanie na konto `root` jest **zablokowane**.
    - Możesz zalogować się tylko jako użytkownik `admin` przy użyciu podanego klucza SSH i nowego portu.
    ```bash
    ssh admin@<IP_SERWERA> -p <NOWY_PORT_SSH>
    ```
3.  **Konfiguracja Weryfikacji Dwuetapowej (TOTP):**
    - Przy pierwszej próbie użycia `sudo` przez użytkownika `admin` (np. `sudo ls /root`), zostaniesz poproszony o skonfigurowanie TOTP.
    - W terminalu wyświetli się **kod QR**. Zeskanuj go aplikacją do uwierzytelniania (np. Google Authenticator, Authy).
    - Zapisz wyświetlone kody zapasowe w bezpiecznym miejscu!
4.  **Dostęp do Usług:**
    Wdrożone usługi będą dostępne pod subdomenami Twojej `PRIMARY_DOMAIN`:
    - **Prometheus:** `https://prometheus.twojadomena.pl`
    - **Grafana:** `https://grafana.twojadomena.pl`
    - **Alertmanager:** `https://alertmanager.twojadomena.pl`
    - **Traefik Dashboard:** Domyślnie nie jest publicznie dostępny. Aby go udostępnić, musiałbyś dodać odpowiednią regułę routingu w plikach konfiguracyjnych Traefik.

5.  **Hasła i Sekrety:**
    - Hasło administratora Grafany jest generowane automatycznie.
    - Wszystkie sekrety są zaszyfrowane w folderze `/opt/services/` przy użyciu `sops`. Aby je odczytać lub edytować, musisz użyć `sops` bezpośrednio na serwerze, np.:
      ```bash
      # To polecenie odszyfruje i wyświetli plik w edytorze
      sudo sops /opt/services/monitoring/secrets/monitoring.env.sops
      ```

## 7. Szczegółowy Opis Działania Skryptu

Skrypt `start.sh` składa się z szeregu funkcji, które są wywoływane po kolei.

- `ensure_root`: Sprawdza, czy skrypt jest uruchamiany z uprawnieniami `root`.
- `install_node_and_gemini`: Instaluje Node.js oraz Gemini CLI.
- `install_base_tools`: Instaluje podstawowe pakiety systemowe, takie jak `ufw` (firewall), `jq` (przetwarzanie JSON), `sops` (zarządzanie sekretami), `age` (szyfrowanie), `aide` (monitorowanie integralności plików) oraz `CrowdSec` (ochrona przed atakami).
- `bootstrap_sops`: Inicjalizuje konfigurację `sops` z kluczem `age`, który będzie używany do szyfrowania wszystkich sekretów.
- `create_admin_user`: Tworzy nowego użytkownika `admin`, dodaje go do grupy `sudo`, konfiguruje logowanie za pomocą klucza SSH i wymusza użycie weryfikacji dwuetapowej (TOTP) przy użyciu `sudo`.
- `harden_ssh`: Zabezpiecza serwer SSH: generuje nowe klucze hosta, blokuje logowanie na konto `root` i za pomocą hasła, zmienia domyślny port na losowy i ogranicza dostęp tylko do autoryzowanych grup.
- `configure_firewall`: Konfiguruje zaporę sieciową `UFW`, otwierając tylko niezbędne porty (nowy port SSH, HTTP, HTTPS, poczta, etc.) i blokując resztę. Dodaje również reguły chroniące kontenery Docker.
- `system_baseline`: Wprowadza zmiany w konfiguracji jądra systemowego w celu poprawy bezpieczeństwa i wydajności. Konfiguruje trwałe logi `journald` oraz automatyczne aktualizacje (`unattended-upgrades`).
- `install_docker`: Instaluje silnik Docker oraz wtyczkę `docker-compose`. Konfiguruje go zgodnie z zaleceniami bezpieczeństwa, m.in. włączając izolację przestrzeni nazw użytkowników (`userns-remap`).
- `prepare_secrets`: Przygotowuje wszystkie potrzebne sekrety (token Cloudflare, hasło do Grafany, hasło do SMTP) i szyfruje je za pomocą `sops`, aby nie były przechowywane na dysku jako jawny tekst.
- `deploy_traefik`: Wdraża kontener z Traefikiem. Konfiguruje go do obsługi ruchu HTTP/HTTPS, automatycznego przekierowywania na HTTPS oraz zamawiania certyfikatów SSL od Let's Encrypt.
- `deploy_monitoring`: Wdraża pełny stos monitoringu, w tym:
  - **Prometheus:** do zbierania danych.
  - **Grafana:** do ich wizualizacji.
  - **Alertmanager:** do wysyłania alertów.
  - **Exportery:** `node-exporter` (metryki systemu), `cAdvisor` (metryki kontenerów), `blackbox-exporter` (monitorowanie dostępności stron).

## 8. Plik `.gitattributes`

```
* text=auto
```
Ta linia w pliku `.gitattributes` jest ważna dla spójności projektu. Nakazuje ona systemowi Git automatyczne zarządzanie znakami końca linii w plikach tekstowych. Dzięki temu unikniesz problemów, jeśli będziesz pracować nad projektem na różnych systemach operacyjnych (np. Windows i Linux), które używają różnych standardów dla końca linii.