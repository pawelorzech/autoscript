<p align="center">
  <a href="#">
    <img src="https://img.shields.io/badge/AutoScript-v5.0-blue.svg" alt="AutoScript Version">
  </a>
  <a href="#7-licencja">
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
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

(Ta sekcja pozostaje taka sama jak w poprzedniej wersji, opisując pozyskiwanie klucza SSH i tokenu Cloudflare. Dodatkowo należy opisać pozyskiwanie kluczy do Backblaze B2).

### Klucze do Kopii Zapasowych (Backblaze B2)

1.  Zaloguj się na swoje konto [Backblaze](https://www.backblaze.com/).
2.  Przejdź do sekcji **"B2 Cloud Storage"** > **"Buckets"** i stwórz nowy, prywatny bucket.
3.  Przejdź do **"App Keys"** i wygeneruj nowy klucz aplikacyjny z dostępem do Twojego bucketa. Będziesz potrzebował `applicationKeyId` (jako `B2_ACCOUNT_ID`) oraz `applicationKey` (jako `B2_ACCOUNT_KEY`).

## 3. Instalacja (Szybki Start)

Proces instalacji pozostaje taki sam jak w poprzednich wersjach, ale teraz wdraża znacznie więcej usług!

## 4. Przewodnik po Komendach

Do istniejącej listy komend dochodzą nowe, dedykowane dla każdej usługi:

- `deploy_discourse`, `deploy_wordpress`, `deploy_freshrss`, `deploy_mail`, `deploy_status`
- `backup:init`, `backup:run`, `backup:restore <snapshot_id>`

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

## 7. Licencja

Projekt jest udostępniany na licencji MIT.
