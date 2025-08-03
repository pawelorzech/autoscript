# AutoScript v3 - Zautomatyzowana Platforma do Zarządzania Serwerem

## 1. Przegląd

AutoScript v3 to ewolucja prostego skryptu w kierunku w pełni modularnej platformy do automatyzacji i zarządzania cyklem życia serwera aplikacyjnego. Narzędzie jest zaprojektowane wokół architektury opartej na komendach, co pozwala na precyzyjne, bezpieczne i idempotentne operacje - od wstępnej konfiguracji po codzienne zarządzanie i deinstalację.

## 2. Kluczowe Koncepcje Architektoniczne

- **Modularność i Komendy**: Zamiast jednego, monolitycznego przebiegu, każdą operację wykonuje się dedykowaną komendą (np. `./start.sh deploy_traefik`).
- **Idempotentność i Paragony (Receipts)**: Skrypt śledzi ukończone instalacje. Można go bezpiecznie uruchamiać wielokrotnie - zainstaluje tylko brakujące elementy.
- **Walidacja "Pre-flight"**: Komenda `validate` sprawdza poprawność konfiguracji *przed* dokonaniem jakichkolwiek zmian w systemie.
- **Bezpieczeństwo jako Priorytet**: Wbudowane wzmacnianie zabezpieczeń, zarządzanie sekretami i przygotowanie pod zaawansowane techniki (AppArmor).

## 3. Dostępne Komendy

Wszystkie komendy należy uruchamiać z uprawnieniami roota, np. `sudo ./start.sh <komenda>`.

| Komenda                 | Opis                                                                                   |
| ----------------------- | -------------------------------------------------------------------------------------- |
| `install`               | **Główna instalacja.** Uruchamia walidację i wdraża wszystkie podstawowe moduły.         |
| `validate`              | Sprawdza poprawność pliku `autoscript.conf` i połączeń z zewnętrznymi API.             |
| `deploy_mastodon`       | (W przygotowaniu) Wdraża i konfiguruje aplikację Mastodon.                               |
| `deploy_traefik`        | Wdraża i konfiguruje reverse proxy Traefik.                                            |
| `deploy_monitoring`     | Wdraża stos monitoringu (Prometheus, Grafana, Alertmanager).                           |
| `secrets:edit <nazwa>`  | Otwiera zaszyfrowany plik z sekretami dla danej usługi w edytorze.                      |
| `secrets:view <nazwa>`  | Wyświetla odszyfrowaną zawartość pliku z sekretami.                                     |
| `self-update`           | Aktualizuje skrypt AutoScript do najnowszej wersji z repozytorium Git.                   |
| `uninstall`             | **Niebezpieczne!** Usuwa wszystkie komponenty, dane i konfiguracje stworzone przez skrypt. |
| `help`                  | Wyświetla listę dostępnych komend.                                                     |

## 4. Instalacja Krok po Kroku

1.  **Zaloguj się jako `root` na nowym serwerze (Debian/Ubuntu).**
2.  **Zainstaluj `git` i sklonuj repozytorium:**
    ```bash
    apt update && apt install -y git
    git clone https://github.com/pawelorzech/autoscript.git
    cd autoscript
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

## 5. Co dalej?

Po zakończeniu instalacji, Twój serwer jest w pełni skonfigurowany i zabezpieczony. Zapoznaj się z krokami opisanymi w poprzednich wersjach `README` (zmiana portu SSH, logowanie jako `admin`, konfiguracja 2FA), ponieważ te zasady wciąż obowiązują.

Możesz teraz zacząć wdrażać właściwą aplikację, np. używając (w przyszłości) komendy `sudo ./start.sh deploy_mastodon`.
