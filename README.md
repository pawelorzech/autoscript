# AutoScript v3 - Zautomatyzowana Platforma do Zarządzania Serwerem

<p align="center">
  <img src="https://img.shields.io/badge/version-3.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/platform-Debian%2FUbuntu-orange.svg" alt="Platform">
</p>

---

## 1. Filozofia i Cele Projektu

AutoScript narodził się z potrzeby stworzenia zautomatyzowanego, bezpiecznego i powtarzalnego procesu konfiguracji serwera. Ręczne przygotowywanie serwera jest czasochłonne i podatne na błędy. Ten projekt ma na celu rozwiązanie tych problemów, kierując się trzema głównymi zasadami:

1.  **Automatyzacja ponad wszystko**: Wszystko, co można zautomatyzować, powinno być zautomatyzowane. Od instalacji pakietów, przez hardening systemu, po wdrożenie aplikacji.
2.  **Bezpieczeństwo Domyślnie (Secure by Default)**: Skrypt wdraża najlepsze praktyki bezpieczeństwa od samego początku, nie jako opcję. Użytkownik nie musi być ekspertem od bezpieczeństwa, aby mieć dobrze zabezpieczony serwer.
3.  **Idempotentność i Niezawodność**: Skrypt można bezpiecznie uruchamiać wielokrotnie. Zawsze doprowadzi system do z góry określonego, pożądanego stanu, instalując tylko brakujące elementy i nie psując istniejących.

## 2. Kluczowe Funkcje w Pigułce

- **Pełna Konfiguracja Systemu**: Od zera do gotowego serwera za pomocą jednej komendy.
- **Modularna Architektura**: Zarządzaj poszczególnymi komponentami (Traefik, Monitoring) za pomocą dedykowanych komend.
- **Hardening Systemu**: Wzmacnianie zabezpieczeń SSH, firewall UFW, `CrowdSec`, `Fail2ban`.
- **Środowisko Kontenerowe**: Wdrożenie Dockera z `userns-remap` i Traefikiem jako reverse proxy.
- **Automatyczne Certyfikaty SSL**: Integracja Traefika z Let's Encrypt i Cloudflare.
- **Zintegrowany Monitoring**: Pełny stos monitoringu (Prometheus, Grafana, Alertmanager) i logów (Loki).
- **Bezpieczne Zarządzanie Sekretami**: Szyfrowanie wszystkich wrażliwych danych (kluczy API, haseł) za pomocą `sops`.
- **Walidacja Konfiguracji**: Sprawdzanie poprawności ustawień przed wprowadzeniem zmian w systemie.
- **Czysta Deinstalacja**: Możliwość bezpiecznego wycofania wszystkich zmian.

## 3. Architektura i Główne Koncepcje

Zrozumienie tych kilku koncepcji jest kluczowe, aby w pełni wykorzystać moc AutoScript.

- **Modularność i Komendy**: Zamiast jednego, monolitycznego skryptu, AutoScript jest sterowany komendami. Każda komenda odpowiada za konkretny, logiczny blok (np. `deploy_traefik`). Daje to pełną kontrolę nad cyklem życia serwera.

- **Idempotentność i Mechanizm "Paragonów"**: Po pomyślnym zakończeniu każdej dużej operacji (np. instalacji Traefika), skrypt tworzy w folderze `/opt/services/.receipts` pusty plik-znacznik (np. `.receipt_traefik`). Przed uruchomieniem jakiejkolwiek operacji, skrypt sprawdza obecność tego "paragonu". Jeśli paragon istnieje, operacja jest pomijana. To gwarantuje, że skrypt nie zepsuje istniejącej konfiguracji i można go bezpiecznie uruchamiać wielokrotnie.

- **Walidacja Konfiguracji ("Pre-flight Check")**: Komenda `validate` to Twoja siatka bezpieczeństwa. Zanim `install` dokona jakiejkolwiek zmiany, `validate` sprawdza, czy klucz API Cloudflare działa, czy domena jest poprawna, czy klucz SSH ma właściwy format itp. To zapobiega błędom w połowie instalacji.

- **Zarządzanie Sekretami (`sops`)**: Żadne hasła, tokeny ani klucze API nie są przechowywane na dysku jako jawny tekst. Wszystkie są szyfrowane w plikach z rozszerzeniem `.sops` przy użyciu klucza `age` generowanego przy pierwszym uruchomieniu. Skrypt automatycznie odszyfrowuje je w pamięci tylko wtedy, gdy są potrzebne.

## 4. Przewodnik po Konfiguracji (`autoscript.conf`)

To serce całego projektu. Poniżej znajduje się szczegółowy opis każdej zmiennej.

| Zmienna                 | Opis                                                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **SEKCJA WYMAGANA**     | **Te wartości MUSZĄ być poprawnie ustawione.**                                                                                   |
| `PUBLIC_KEY`            | Twój publiczny klucz SSH (zawartość pliku `~/.ssh/id_ed25519.pub`). Niezbędny do logowania po rekonfiguracji SSH.                |
| `CF_DNS_API_TOKEN`      | Token API z Cloudflare z uprawnieniami `Zone:DNS:Edit` dla Twojej domeny.                                                         |
| **USTAWIENIA GŁÓWNE**   |                                                                                                                                 |
| `PRIMARY_DOMAIN`        | Główna domena, na której będzie działać główna aplikacja (np. Mastodon). Przykład: `social.ovh`.                                 |
| `SERVICES_DOMAIN`       | Domena dla usług pomocniczych (Grafana, Prometheus). Domyślnie jest to ta sama co `PRIMARY_DOMAIN`.                               |
| `ADMIN_EMAIL`           | Adres e-mail używany do powiadomień od Let's Encrypt i alertów systemowych.                                                       |
| `TIMEZONE`              | Strefa czasowa serwera, np. `Europe/Warsaw`.                                                                                     |
| **MODUŁY OPCJONALNE**   | Włącz (`true`) lub wyłącz (`false`) instalację dodatkowych komponentów.                                                          |
| `INSTALL_FAIL2BAN`      | Instaluje Fail2ban jako dodatkową warstwę ochrony. Zalecane.                                                                    |
| `INSTALL_DATABASE`      | Wdraża kontener z bazą danych PostgreSQL. Wymagane przez wiele aplikacji, w tym Mastodon.                                       |
| `INSTALL_LOKI`          | Wdraża system centralnego zbierania logów Loki. Bardzo przydatne do debugowania.                                                |
| `INSTALL_BACKUP`        | Konfiguruje system kopii zapasowych Restic. Wymaga ręcznego uzupełnienia danych dostępowych do chmury.                            |
| `ENABLE_APPARMOR`       | (Eksperymentalne) Włącza generowanie profili bezpieczeństwa AppArmor dla kontenerów.                                            |
| **POZOSTAŁE SEKCJE**    |                                                                                                                                 |
| `ALERT_SMTP_*`          | Pełna konfiguracja serwera SMTP do wysyłania alertów z monitoringu.                                                              |
| `POSTGRES_PASSWORD`     | Hasło dla bazy danych. Jeśli pozostawione puste, zostanie wygenerowane losowe.                                                  |
| `BACKUP_*`              | Pełna konfiguracja dla Restic, w tym dane dostępowe do repozytorium w chmurze.                                                  |
| `*_VER`                 | Wersje obrazów Docker. Pozwala "przypiąć" konkretne wersje oprogramowania dla zapewnienia stabilności.                          |

## 5. Instalacja i Użycie

### Szybki Start (Instalacja na Nowym Serwerze)

1.  **Zaloguj się jako `root` na nowym serwerze (Debian/Ubuntu).**
2.  **Zainstaluj `git` i sklonuj repozytorium:**
    ```bash
    apt update && apt install -y git
    git clone https://github.com/pawelorzech/autoscript.git && cd autoscript
    ```
3.  **Skonfiguruj AutoScript:**
    ```bash
    cp autoscript.conf.example autoscript.conf
    nano autoscript.conf # Wypełnij wszystkie zmienne zgodnie z przewodnikiem powyżej
    ```
4.  **Sprawdź poprawność konfiguracji:**
    ```bash
    sudo ./start.sh validate
    ```
5.  **Uruchom pełną instalację:**
    ```bash
    sudo ./start.sh install
    ```

### Szczegółowy Opis Komend

| Komenda                 | Opis                                                                                                                            |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `install`               | Meta-komenda, która uruchamia w odpowiedniej kolejności wszystkie niezbędne moduły instalacyjne. Idealna na start.                |
| `validate`              | Sprawdza poprawność pliku konfiguracyjnego i połączeń z zewnętrznymi API (np. Cloudflare). Nie wprowadza żadnych zmian.          |
| `deploy_mastodon`       | (W przygotowaniu) W pełni automatyzuje wdrożenie i konfigurację aplikacji Mastodon.                                               |
| `deploy_traefik`        | Wdraża i konfiguruje reverse proxy Traefik.                                                                                     |
| `deploy_monitoring`     | Wdraża pełny stos monitoringu (Prometheus, Grafana, Alertmanager) i logowania (Loki).                                           |
| `secrets:edit <nazwa>`  | Bezpiecznie otwiera zaszyfrowany plik z sekretami dla danej usługi (np. `traefik`) w domyślnym edytorze.                          |
| `secrets:view <nazwa>`  | Bezpiecznie wyświetla odszyfrowaną zawartość pliku z sekretami.                                                                  |
| `self-update`           | Aktualizuje skrypt AutoScript do najnowszej wersji z repozytorium Git.                                                            |
| `uninstall`             | **BARDZO NIEBEZPIECZNE!** Usuwa wszystkie komponenty, dane i konfiguracje stworzone przez skrypt, bazując na zapisanych paragonach. |

## 6. Aspekty Bezpieczeństwa

AutoScript traktuje bezpieczeństwo jako fundamentalny element, a nie dodatek.

- **Hardening Systemu**: Skrypt automatycznie zmienia domyślny port SSH, blokuje logowanie na konto `root`, wyłącza logowanie hasłem (wymuszając użycie kluczy SSH) i konfiguruje uwierzytelnianie dwuetapowe (TOTP) dla komendy `sudo`.
- **Firewall (UFW)**: Konfigurowana jest zapora sieciowa, która domyślnie blokuje cały ruch przychodzący, otwierając tylko niezbędne porty (SSH, HTTP/S, poczta).
- **Ochrona przed Włamaniami**: Instalowany jest `CrowdSec` (nowoczesny, oparty na reputacji IPS) oraz opcjonalnie `Fail2ban` (klasyczna ochrona logów).
- **Bezpieczeństwo Kontenerów**: Docker jest konfigurowany z `userns-remap`, co mapuje użytkownika `root` wewnątrz kontenera na zwykłego użytkownika na hoście, znacząco ograniczając potencjalne szkody w razie "ucieczki" z kontenera.
- **Zarządzanie Sekretami**: Jak wspomniano, wszystkie wrażliwe dane są szyfrowane na dysku za pomocą `sops`.

## 7. Rozwiązywanie Problemów (Troubleshooting)

- **Instalacja nie powiodła się?** Pierwszym krokiem jest zawsze sprawdzenie pliku logu: `less /var/log/autoscript.log`. Zawiera on szczegółowe informacje o każdej operacji.
- **Błędy konfiguracyjne?** Uruchom `./start.sh validate`, aby upewnić się, że wszystkie ustawienia są poprawne.
- **Problem z certyfikatem SSL?** Upewnij się, że Twoja domena poprawnie wskazuje na adres IP serwera, a token Cloudflare ma odpowiednie uprawnienia.

## 8. Roadmapa i Przyszły Rozwój

AutoScript jest aktywnie rozwijany. Poniżej znajduje się lista planowanych funkcji, dla których przygotowano już fundamenty w kodzie:

- [ ] **Pełna implementacja `deploy_mastodon`**.
- [ ] **Dynamiczne odkrywanie usług** dla Prometheus na podstawie etykiet Docker.
- [ ] **Centralne logowanie dla hosta** (przesyłanie logów z `/var/log` do Loki).
- [ ] **Tryb interaktywnej konfiguracji** (`interactive_setup`).
- [ ] **Generowanie profili AppArmor** dla kluczowych kontenerów.
- [ ] **Zaawansowane komendy do zarządzania kopiami zapasowymi** (`backup:run`, `backup:restore`).

## 9. Kontrybucja

Pomysły, zgłoszenia błędów i pull requesty są mile widziane! Proszę tworzyć zgłoszenia (issues) w repozytorium GitHub, aby omówić większe zmiany.

## 10. Licencja

Projekt jest udostępniany na licencji MIT.