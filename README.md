# AutoScript v2 - Zautomatyzowana Konfiguracja i Zarządzanie Serwerem

## 1. Przegląd

AutoScript to potężne narzędzie do automatyzacji pełnego cyklu życia serwera opartego o system Debian/Ubuntu. Skrypt przekształca "surowy" serwer w gotowe do pracy, zabezpieczone i monitorowane środowisko produkcyjne. Dzięki modularnej budowie, możesz używać go zarówno do wstępnej konfiguracji, jak i do późniejszego zarządzania poszczególnymi komponentami.

## 2. Główne Funkcje

- **Modularność**: Uruchamiaj tylko te części skryptu, których potrzebujesz (`install`, `deploy_monitoring`, `uninstall` itp.).
- **Automatyzacja i Idempotentność**: Skrypt można bezpiecznie uruchamiać wielokrotnie - zawsze doprowadzi system do pożądanego stanu.
- **Hardening (Wzmacnianie Zabezpieczeń)**: Kompleksowe zabezpieczenie serwera, w tym firewall, niestandardowy port SSH, blokada roota, uwierzytelnianie kluczem, `CrowdSec` i opcjonalnie `Fail2ban`.
- **Środowisko Docker**: Wdrożenie Dockera z Traefikiem jako reverse proxy i automatycznymi certyfikatami SSL.
- **Monitoring i Alerty**: Pełny stos monitoringu (Prometheus, Grafana, Alertmanager) z prekonfigurowanymi regułami.
- **Zarządzanie Sekretami**: Bezpieczne przechowywanie haseł i kluczy API dzięki `sops`.
- **Funkcje Opcjonalne**: Możliwość łatwego doinstalowania bazy danych PostgreSQL, systemu logów Loki czy kopii zapasowych Restic.
- **Czysta Deinstalacja**: Możliwość wycofania wszystkich zmian za pomocą jednej komendy.

## 3. Struktura Projektu

```
autoscript/
├── templates/           # Szablony plików konfiguracyjnych
│   ├── monitoring/
│   └── traefik/
├── autoscript.conf.example # Przykład pliku konfiguracyjnego
├── CHANGELOG.md         # Dziennik zmian
├── README.md            # Ta dokumentacja
└── start.sh             # Główny skrypt wykonawczy
```

## 4. Skąd wziąć wymagane klucze?

Plik `autoscript.conf` wymaga podania dwóch kluczowych informacji. Oto jak je zdobyć:

### 1. `PUBLIC_KEY` (Publiczny klucz SSH)

Klucz SSH służy do bezpiecznego logowania na serwer bez hasła. Składa się z dwóch części: prywatnej (którą trzymasz na swoim komputerze) i publicznej (którą wgrywasz na serwer).

**Jeśli nie masz jeszcze klucza SSH:**

Otwórz terminal na swoim komputerze (Linux, macOS) lub Git Bash/WSL (Windows) i wpisz:

```bash
ssh-keygen -t ed25519 -C "twoj_email@example.com"
```

Naciśnij Enter, aby zaakceptować domyślną lokalizację zapisu. Możesz opcjonalnie podać hasło do klucza dla dodatkowego bezpieczeństwa.

**Aby uzyskać wartość do wklejenia:**

Wyświetl zawartość swojego klucza publicznego. Domyślnie znajduje się on w pliku `~/.ssh/id_ed25519.pub`. Użyj komendy:

```bash
cat ~/.ssh/id_ed25519.pub
```

Skopiuj całą wyświetloną linię (zaczynającą się od `ssh-ed25519 ...`) i wklej ją jako wartość zmiennej `PUBLIC_KEY` w pliku `autoscript.conf`.

### 2. `CF_DNS_API_TOKEN` (Token API Cloudflare)

Ten token pozwala skryptowi na automatyczne zarządzanie rekordami DNS Twojej domeny, co jest niezbędne do generowania certyfikatów SSL przez Traefik.

1.  **Zaloguj się** na swoje konto [Cloudflare](https://dash.cloudflare.com).
2.  Przejdź do sekcji **"My Profile"** (w prawym górnym rogu) > **"API Tokens"**.
    - *Bezpośredni link:* [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
3.  Kliknij przycisk **"Create Token"**.
4.  Znajdź szablon **"Edit zone DNS"** i kliknij **"Use template"**.
5.  Skonfiguruj token:
    - **Permissions**: Upewnij się, że jest `Zone:DNS:Edit`.
    - **Zone Resources**: Wybierz `Include` > `Specific zone` > i wybierz z listy swoją domenę, którą będziesz zarządzać.
    - **Client IP Address Filtering** i **TTL**: Możesz pozostawić domyślne.
6.  Kliknij **"Continue to summary"**, a następnie **"Create Token"**.
7.  **Skopiuj wygenerowany token.** To jedyny moment, kiedy jest on w pełni widoczny. Wklej go jako wartość zmiennej `CF_DNS_API_TOKEN` w pliku `autoscript.conf`.

## 5. Szybki Start: Instalacja na Nowym Serwerze

Ta instrukcja poprowadzi Cię krok po kroku przez proces wdrożenia na świeżo zainstalowanym serwerze z systemem Debian 12 lub Ubuntu 22.04+.

### Krok 1: Zaloguj się jako root i zainstaluj `git`

Połącz się z nowym serwerem jako użytkownik `root`. Następnie zaktualizuj listę pakietów i zainstaluj `git`:

```bash
apt update
apt install -y git
```

### Krok 2: Sklonuj repozytorium

Będąc w katalogu domowym roota (`/root`), sklonuj ten projekt:

```bash
git clone https://github.com/pawelorzech/autoscript.git
cd autoscript
```

### Krok 3: Skonfiguruj skrypt

Skopiuj plik z przykładem, aby stworzyć własną konfigurację:

```bash
cp autoscript.conf.example autoscript.conf
```

Teraz musisz edytować ten plik. Użyj prostego edytora, np. `nano`:

```bash
nano autoscript.conf
```

Postępuj zgodnie z instrukcją z sekcji **"Skąd wziąć wymagane klucze?"**, aby wypełnić `PUBLIC_KEY` i `CF_DNS_API_TOKEN`. Przejrzyj też inne zmienne i dostosuj je do swoich potrzeb. Zapisz plik i wyjdź z edytora (w `nano`: `Ctrl+X`, potem `Y` i `Enter`).

### Krok 4: Uruchom instalację

Upewnij się, że jesteś w folderze `autoscript`. Teraz uruchom główną komendę instalacyjną. Skrypt musi być wykonany z uprawnieniami roota.

```bash
./start.sh install
```

Skrypt rozpocznie pracę. Proces może potrwać od kilku do kilkunastu minut. Na ekranie będą wyświetlane logi z postępu prac.

### Krok 5: Ważne kroki po instalacji

Gdy skrypt zakończy pracę z komunikatem o sukcesie, Twoje środowisko jest gotowe, ale zaszły kluczowe zmiany w zabezpieczeniach:

1.  **Logowanie na `root` jest ZABLOKOWANE.**
2.  **Port SSH został ZMIENIONY** na losowy numer. Aby go poznać, wykonaj:
    ```bash
    cat /root/ssh_port.txt
    ```
3.  **Nowy użytkownik `admin` został stworzony.** Możesz się na niego zalogować, używając swojego klucza SSH i nowego portu:
    ```bash
    ssh admin@<IP_TWOJEGO_SERWERA> -p <NOWY_PORT_Z_PLIKU>
    ```
4.  **Konfiguracja 2FA (TOTP):** Przy pierwszej próbie użycia `sudo` (np. `sudo ls /root`), na ekranie pojawi się kod QR. Zeskanuj go aplikacją typu Google Authenticator lub Authy i **zapisz kody zapasowe w bezpiecznym miejscu!**

Twoja instalacja jest zakończona i serwer jest zabezpieczony. Dalsze zarządzanie możesz prowadzić za pomocą pozostałych komend skryptu (np. `./start.sh deploy_database`).

## 6. Opis Modułów Opcjonalnych

Możesz włączyć je w pliku `autoscript.conf`.

- **Fail2ban**: Dodatkowa ochrona, która analizuje logi i blokuje adresy IP wykazujące złośliwą aktywność (np. próby logowania brute-force).
- **PostgreSQL**: Wdraża kontener z popularną bazą danych. Hasło jest zarządzane przez `sops`.
- **Loki**: System do agregacji logów z Twoich kontenerów. Umożliwia ich wygodne przeszukiwanie w Grafanie.
- **Restic Backup**: Instaluje i konfiguruje `restic` do tworzenia regularnych, szyfrowanych kopii zapasowych do chmury (np. AWS S3, Backblaze B2). **Wymaga dodatkowej konfiguracji po stronie dostawcy chmury!**

## 7. Co robić po instalacji?

Po zakończeniu komendy `install`:

1.  **Nowy Port SSH:** Został zmieniony na losowy. Znajdziesz go w pliku `/root/ssh_port.txt`.
2.  **Logowanie**: Logowanie na `root` jest zablokowane. Użyj użytkownika `admin` z Twoim kluczem SSH i nowym portem: `ssh admin@<IP> -p <PORT>`.
3.  **TOTP (2FA)**: Przy pierwszym użyciu `sudo` zostaniesz poproszony o skonfigurowanie aplikacji do uwierzytelniania (np. Google Authenticator).
4.  **Dostęp do usług**: Usługi będą dostępne pod subdomenami Twojej domeny (np. `https://grafana.social.ovh`).