<p align="center">
  <a href="#">
    <img src="https://img.shields.io/badge/AutoScript-v5.0-blue.svg" alt="AutoScript Version">
  </a>
  <a href="#7-licencja">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  </a>
  <a href="README_en.md">
    <img src="https://img.shields.io/badge/lang-EN-blue.svg" alt="English">
  </a>
</p>

<h1 align="center">AutoScript: Zintegrowana Platforma Serwerowa</h1>

**AutoScript to w pełni zintegrowane, zautomatyzowane i bezpieczne rozwiązanie do wdrażania i zarządzania kompletną, wielousługową platformą serwerową.** Ten projekt przekształca "surowy" serwer w gotowe do pracy, zabezpieczone i monitorowane środowisko, zdolne do hostowania szerokiej gamy aplikacji jednocześnie.

---

## Spis Treści

1.  [Architektura Platformy: Przegląd Usług](#1-architektura-platformy-przegląd-usług)
2.  [Przewodnik Konfiguracyjny: Zdobywanie Kluczy](#2-przewodnik-konfiguracyjny-zdobywanie-kluczy)
3.  [Instalacja (Szybki Start)](#3-instalacja-szybki-start)
4.  [Przewodnik po Komendach](#4-przewodnik-po-komendach)
5.  [Kopie Zapasowe i Odtwarzanie](#5-kopie-zapasowe-i-odtwarzanie)
6.  [Aspekty Bezpieczeństwa](#6-aspekty-bezpieczeństwa)
7.  [Licencja](#7-licencja)

---

## 1. Architektura Platformy: Przegląd Usług

AutoScript buduje kompleksowy ekosystem usług, gotowych do użycia zaraz po instalacji:

| Kategoria             | Usługa                                  | Rola w Systemie                                                                                             |
| --------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Sieci Społecznościowe** | **Mastodon**                            | Zdecentralizowana, federacyjna sieć społecznościowa.                                                        |
| **Forum Dyskusyjne**  | **Discourse**                           | Nowoczesna, w pełni funkcjonalna platforma do prowadzenia forów internetowych.                                |
| **System Blogowy**    | **WordPress**                           | Najpopularniejszy na świecie system zarządzania treścią (CMS), idealny do prowadzenia bloga lub strony.       |
| **Czytnik RSS**       | **FreshRSS**                            | Osobisty agregator wiadomości i czytnik kanałów RSS, hostowany na własnym serwerze.                          |
| **Poczta E-mail**     | **Własny serwer poczty**                | Kompletny, samowystarczalny serwer pocztowy (IMAP/SMTP) z panelem administracyjnym.                           |
| **Synchronizacja Poczty** | **imapsync**                            | Narzędzie do masowej migracji i synchronizacji kont e-mail między serwerami.                                |
| **Monitoring i Status** | **Uptime Kuma**                         | Pulpit do monitorowania dostępności wszystkich Twoich usług z publiczną stroną statusu.                     |
| **Infrastruktura**    | **Traefik, Docker, PostgreSQL, etc.**   | Solidny fundament składający się z reverse proxy, konteneryzacji i baz danych.                                |

## 2. Przewodnik Konfiguracyjny: Zdobywanie Kluczy

### Klucz SSH

1. Wygeneruj parę kluczy SSH na swoim lokalnym komputerze:
   ```bash
   ssh-keygen -t ed25519 -C "twoj-email@example.com"
   ```
2. Skopiuj zawartość klucza publicznego:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
3. Użyj tej zawartości jako wartość `PUBLIC_KEY` w pliku konfiguracyjnym.

### Token API Cloudflare

1. Zaloguj się do [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Przejdź do **My Profile** > **API Tokens**
3. Kliknij **Create Token** i wybierz szablon **Custom token**
4. Ustaw uprawnienia:
   - Zone: Zone:Read
   - Zone: DNS:Edit
5. Wybierz odpowiednią strefę DNS
6. Skopiuj wygenerowany token jako `CF_DNS_API_TOKEN`

### Klucze do Kopii Zapasowych (Backblaze B2)

1.  Zaloguj się na swoje konto [Backblaze](https://www.backblaze.com/).
2.  Przejdź do sekcji **"B2 Cloud Storage"** > **"Buckets"** i stwórz nowy, prywatny bucket.
3.  Przejdź do **"App Keys"** i wygeneruj nowy klucz aplikacyjny z dostępem do Twojego bucketa. Będziesz potrzebował `applicationKeyId` (jako `B2_ACCOUNT_ID`) oraz `applicationKey` (jako `B2_ACCOUNT_KEY`).

## 3. Instalacja: Od Zera do Działającej Platformy

Ta sekcja to szczegółowy, kompletny przewodnik, który poprowadzi Cię od zera do w pełni działającej, bezpiecznej platformy. Wykonuj polecenia w podanej kolejności. Zakładamy, że zaczynasz od świeżo zainstalowanego serwera z systemem **Debian 12** lub **Ubuntu 22.04+**.

### Krok 1: Pierwsze Połączenie z Serwerem

Zaraz po stworzeniu serwera u swojego dostawcy hostingu, otrzymasz adres IP. Połącz się z serwerem jako użytkownik `root` za pomocą terminala SSH. Na swoim lokalnym komputerze (Linux, macOS, Windows z WSL lub Git Bash) wpisz:

```bash
ssh root@<IP_TWOJEGO_SERWERA>
```

Będziesz poproszony o hasło roota, które dostarczył Twój hostingodawca.

### Krok 2: Pobranie AutoScript

Będąc zalogowanym jako `root` na serwerze, Twoim pierwszym zadaniem jest instalacja `git` (jeśli go nie ma) i pobranie kodu AutoScript. Wszystkie poniższe komendy wykonujesz **na serwerze**.

```bash
# Aktualizuje listę dostępnych pakietów i instaluje git
apt update && apt install -y git

# Klonuje repozytorium do folderu /root/autoscript i przechodzi do niego
git clone https://github.com/pawelorzech/autoscript.git && cd autoscript
```

### Krok 3: Konfiguracja Platformy

To najważniejszy krok, w którym definiujesz, jak będzie działać Twoja platforma. Musisz stworzyć plik konfiguracyjny i wypełnić go swoimi danymi.

```bash
# Tworzy kopię pliku z przykładem
cp autoscript.conf.example autoscript.conf

# Otwiera plik konfiguracyjny w prostym edytorze tekstu
nano autoscript.conf
```

Otworzy się edytor `nano`. Użyj strzałek, aby poruszać się po pliku. Uważnie wypełnij **wszystkie wymagane zmienne**, postępując zgodnie z instrukcjami z sekcji "Przewodnik Konfiguracyjny: Zdobywanie Kluczy". Zwróć szczególną uwagę na `PUBLIC_KEY`, `CF_DNS_API_TOKEN` oraz domeny dla poszczególnych usług.

**Aby zapisać plik i wyjść z edytora `nano`:**
1.  Naciśnij `Ctrl + X`.
2.  Naciśnij `Y` (aby potwierdzić chęć zapisu).
3.  Naciśnij `Enter` (aby potwierdzić nazwę pliku).

### Krok 4: Walidacja Konfiguracji

Zanim dokonasz jakichkolwiek zmian w systemie, uruchom walidację. Skrypt sprawdzi, czy klucze API są poprawne i czy może połączyć się z wymaganymi usługami. To Twoja siatka bezpieczeństwa.

```bash
# Upewnij się, że jesteś w folderze /root/autoscript
sudo ./start.sh validate
```

Jeśli walidacja zakończy się sukcesem, jesteś gotowy do instalacji. Jeśli nie, skrypt poinformuje Cię, co należy poprawić w pliku `autoscript.conf`.

### Krok 5: Uruchomienie Instalacji

Wykonaj główną komendę instalacyjną. Skrypt zajmie się resztą. Usiądź wygodnie, proces może potrwać od kilku do kilkunastu minut.

```bash
# Upewnij się, że jesteś w folderze /root/autoscript
sudo ./start.sh install
```

Skrypt zainstaluje wszystkie pakiety, skonfiguruje zabezpieczenia, wdroży wszystkie usługi w kontenerach Docker i połączy je w jeden sprawnie działający ekosystem.

### Krok 6: Kroki Po Instalacji (Bardzo Ważne!)

Gdy skrypt zakończy pracę, Twój serwer jest gotowy, ale jego zabezpieczenia zostały fundamentalnie zmienione:

1.  **Logowanie na `root` jest ZABLOKOWANE.**
2.  **Port SSH został ZMIENIONY** na losowy numer z zakresu 10000-65535. Aby go poznać, wykonaj na serwerze:
    ```bash
    cat /root/ssh_port.txt
    ```
3.  **Nowy użytkownik `admin` został stworzony.** Od teraz logujesz się tylko na to konto, używając swojego klucza SSH i nowego portu. Na **swoim lokalnym komputerze** wykonaj:
    ```bash
    ssh admin@<IP_TWOJEGO_SERWERA> -p <NOWY_PORT_Z_PLIKU>
    ```
4.  **Konfiguracja 2FA (TOTP):** Przy pierwszej próbie użycia `sudo` (np. `sudo ls /root`), na ekranie pojawi się kod QR. Zeskanuj go aplikacją typu Google Authenticator lub Authy i **zapisz kody zapasowe w bezpiecznym miejscu!** Są one jednorazowe i niezbędne do odzyskania dostępu w razie utraty telefonu.

Twoja platforma jest gotowa do użytku. Usługi będą dostępne pod domenami skonfigurowanymi w pliku `autoscript.conf`.

## 4. Przewodnik po Komendach

AutoScript jest sterowany za pomocą prostych, logicznych komend. Wszystkie komendy należy uruchamiać z folderu `/root/autoscript` z uprawnieniami `sudo`.

### Komendy Główne

- `sudo ./start.sh install`
  **Meta-komenda, której użyjesz raz na początku.** Uruchamia w odpowiedniej kolejności wszystkie niezbędne moduły instalacyjne: walidację, hardening systemu, wdrażanie Traefika, monitoringu i wszystkich skonfigurowanych usług. Idealna do szybkiego startu.

- `sudo ./start.sh uninstall`
  **BARDZO NIEBEZPIECZNE!** Ta komenda całkowicie usuwa **wszystko**, co zostało stworzone przez AutoScript: kontenery, dane aplikacji, wolumeny, obrazy Docker, a nawet odinstalowuje pakiety. Używaj tylko wtedy, gdy chcesz całkowicie wyczyścić serwer. Skrypt poprosi o potwierdzenie, aby zapobiec przypadkowemu użyciu.

- `sudo ./start.sh validate`
  **Twoja siatka bezpieczeństwa.** Sprawdza poprawność pliku `autoscript.conf`, weryfikuje klucze API i tokeny, ale **nie wprowadza żadnych zmian w systemie**. Zawsze uruchamiaj tę komendę po zmianie konfiguracji.

### Komendy do Zarządzania Usługami

Możesz zarządzać każdą usługą niezależnie. Jest to przydatne do ponownego wdrożenia lub aktualizacji konkretnego komponentu.

- `sudo ./start.sh deploy_mastodon`
- `sudo ./start.sh deploy_discourse`
- `sudo ./start.sh deploy_wordpress`
- `sudo ./start.sh deploy_freshrss`
- `sudo ./start.sh deploy_mail`
- `sudo ./start.sh deploy_status`
- `sudo ./start.sh deploy_monitoring`
- `sudo ./start.sh deploy_traefik`

### Komendy do Zarządzania Kopiami Zapasowymi

- `sudo ./start.sh backup:init`
  Inicjalizuje nowe, puste repozytorium kopii zapasowych w Twoim buckecie Backblaze B2. **Musisz to zrobić raz, zanim zadziała automatyczny backup.**

- `sudo ./start.sh backup:run`
  Ręcznie uruchamia proces tworzenia nowej, szyfrowanej kopii zapasowej całego folderu `/opt/services`.

- `sudo ./start.sh backup:list`
  Wyświetla listę wszystkich dostępnych migawek (snapshotów) w Twoim repozytorium kopii zapasowych.

- `sudo ./start.sh backup:restore <ID_MIGAWKI>`
  Odtwarza wybraną migawkę do folderu `/opt/services.restored`. Nie nadpisuje istniejących danych, dając Ci pełną kontrolę nad procesem przywracania.

### Komendy Narzędziowe

- `sudo ./start.sh secrets:edit <nazwa_usługi>`
  Bezpiecznie otwiera zaszyfrowany plik z sekretami dla danej usługi (np. `mastodon`) w domyślnym edytorze. Po zapisaniu plik jest automatycznie ponownie szyfrowany.

- `sudo ./start.sh secrets:view <nazwa_usługi>`
  Bezpiecznie wyświetla na ekranie odszyfrowaną zawartość pliku z sekretami, nie zapisując jej nigdzie w formie jawnego tekstu.

- `sudo ./start.sh self-update`
  Aktualizuje skrypt AutoScript do najnowszej wersji z repozytorium Git. Zalecane do regularnego uruchamiania.

## 5. Kopie Zapasowe i Odtwarzanie

AutoScript jest w pełni zintegrowany z `Restic` i `Backblaze B2`, aby zapewnić bezpieczeństwo Twoich danych.

- **Automatyzacja**: Po poprawnej konfiguracji, skrypt automatycznie tworzy zadanie `cron`, które codziennie wykonuje szyfrowaną kopię zapasową całego folderu `/opt/services` (zawierającego wszystkie dane aplikacji) do Twojego bucketa B2.
- **Odtwarzanie**: W razie awarii, możesz użyć komendy `sudo ./start.sh backup:restore <ID_MIGAWKI>`, aby przywrócić dane.

## 6. Aspekty Bezpieczeństwa: Architektura "Secure by Default"

AutoScript nie traktuje bezpieczeństwa jako opcji, ale jako fundamentalny element wbudowany w każdy aspekt platformy. Oto kluczowe mechanizmy obronne, które są wdrażane automatycznie:

### Poziom Systemu Operacyjnego

- **Minimalizacja Powierzchni Ataku**: Skrypt instaluje tylko niezbędne pakiety. Nie ma zbędnego oprogramowania, które mogłoby stanowić potencjalne zagrożenie.
- **Wzmocnione Uwierzytelnianie**: Logowanie hasłem do SSH jest całkowicie wyłączone. Dostęp jest możliwy tylko za pomocą kluczy kryptograficznych. Dodatkowo, dostęp do uprawnień `root` (przez `sudo`) jest chroniony przez uwierzytelnianie dwuetapowe (TOTP).
- **Ograniczenie Dostępu**: Logowanie na konto `root` jest zablokowane. Dedykowany użytkownik `admin` ma ograniczone uprawnienia, które może podnieść tylko za pomocą `sudo` (z weryfikacją 2FA).
- **Firewall (UFW)**: Zapora sieciowa jest skonfigurowana w trybie "blokuj wszystko, zezwalaj na wybrane". Otwierane są tylko porty niezbędne do działania wdrożonych usług.

### Poziom Aplikacji i Sieci

- **Proaktywna Ochrona przed Włamaniami (IPS)**: `CrowdSec` analizuje zachowanie w sieci i proaktywnie blokuje adresy IP znane ze złośliwej aktywności na całym świecie. `Fail2ban` dodatkowo monitoruje logi w poszukiwaniu prób ataków brute-force.
- **Szyfrowanie End-to-End**: Cały ruch do Twoich usług jest automatycznie szyfrowany za pomocą certyfikatów SSL/TLS od Let's Encrypt, zarządzanych przez Traefik.
- **Izolacja Kontenerów**: Wszystkie usługi działają w kontenerach Docker, co izoluje je od siebie i od systemu hosta. Dodatkowo, włączenie `userns-remap` mapuje użytkownika `root` wewnątrz kontenera na zwykłego użytkownika na hoście, co drastycznie ogranicza potencjalne szkody w razie "ucieczki" z kontenera.

### Poziom Danych

- **Zarządzanie Sekretami (`sops`)**: Wszystkie wrażliwe dane – klucze API, hasła do baz danych, tokeny – są szyfrowane na dysku za pomocą `sops` i klucza `age`. Nigdy nie są przechowywane jako jawny tekst.
- **Szyfrowane Kopie Zapasowe**: Wszystkie kopie zapasowe tworzone przez `Restic` są szyfrowane end-to-end przed wysłaniem ich do zewnętrznej lokalizacji (Backblaze B2). Bez hasła do repozytorium nikt nie jest w stanie odczytać Twoich danych.

## 7. Kroki po Instalacji: Co Dalej?

Gratulacje! Twoja platforma jest w pełni zainstalowana, zabezpieczona i gotowa do pracy. Oto co powinieneś zrobić teraz, aby w pełni przejąć nad nią kontrolę i zacząć z niej korzystać.

### 1. Pierwsze Logowanie i Konfiguracja Aplikacji

Każda z zainstalowanych usług jest teraz dostępna pod domeną, którą skonfigurowałeś w pliku `autoscript.conf`. Czas je odwiedzić i dokończyć ich konfigurację z poziomu interfejsu webowego.

- **Mastodon (`https://twoja-domena.ovh`)**: Przejdź na stronę główną i zarejestruj swoje pierwsze konto. Pierwsze zarejestrowane konto automatycznie otrzymuje rolę właściciela instancji.
- **Discourse (`https://forum.twoja-domena.ovh`)**: Podobnie jak w Mastodonie, zarejestruj konto administratora, aby zacząć konfigurować kategorie i ustawienia forum.
- **WordPress (`https://blog.twoja-domena.ovh`)**: Przejdź przez słynny "pięciominutowy instalator" WordPressa, aby ustawić tytuł strony, stworzyć konto administratora i zacząć pisać.
- **FreshRSS (`https://rss.twoja-domena.ovh`)**: Zaloguj się i zacznij dodawać swoje ulubione kanały RSS.
- **Serwer Poczty (`https://twoja-domena.ovh/admin`)**: Zaloguj się do panelu administracyjnego poczty, używając hasła `MAIL_ADMIN_PASSWORD` z pliku konfiguracyjnego. Tutaj możesz dodawać domeny i skrzynki pocztowe.
- **Pulpit Statusu (`https://status.twoja-domena.ovh`)**: Skonfiguruj Uptime Kuma, tworząc monitory dla wszystkich swoich nowych usług, aby śledzić ich dostępność.

### 2. Dostęp do Danych i Sekretów

Wszystkie dane Twoich aplikacji (bazy danych, wgrane pliki) znajdują się w folderze `/opt/services/`. Możesz je przeglądać jako użytkownik `admin`.

Jeśli potrzebujesz sprawdzić wygenerowane hasło do bazy danych lub inny sekret, użyj wbudowanej komendy:

```bash
sudo ./start.sh secrets:view <nazwa_usługi>
# Przykład:
sudo ./start.sh secrets:view mastodon
```

### 3. Zarządzanie Kopiami Zapasowymi

Kopie zapasowe są skonfigurowane, ale warto sprawdzić ich status. Możesz ręcznie uruchomić backup lub wylistować istniejące migawki.

```bash
# Ręczne uruchomienie kopii zapasowej
sudo ./start.sh backup:run

# Wyświetlenie listy wszystkich kopii w repozytorium
sudo ./start.sh backup:list
```

### 4. Monitorowanie Systemu

Zapoznaj się z pulpitem Grafany, aby zobaczyć, jak pracuje Twój serwer.

- **Grafana (`https://grafana.twoja-domena.ovh`)**: Zaloguj się, używając hasła `GRAFANA_ADMIN_PASSWORD` z pliku konfiguracyjnego. Znajdziesz tam prekonfigurowane dashboardy pokazujące użycie CPU, pamięci, stan kontenerów i wiele więcej.
- **Alertmanager (`https://alertmanager.twoja-domena.ovh`)**: Tutaj możesz zobaczyć aktywne alerty. Domyślnie są one wysyłane na Twój `ADMIN_EMAIL`.

### 5. Aktualizacje

Pamiętaj, aby regularnie aktualizować zarówno system operacyjny, jak i sam skrypt AutoScript.

```bash
# Aktualizacja pakietów systemowych
sudo apt update && sudo apt upgrade -y

# Aktualizacja AutoScript do najnowszej wersji
sudo ./start.sh self-update
```

Twoja platforma jest teraz w pełni w Twoich rękach. Eksperymentuj, twórz i ciesz się wolnością posiadania własnej, potężnej infrastruktury!

## 8. Licencja

Projekt jest udostępniany na licencji MIT.
