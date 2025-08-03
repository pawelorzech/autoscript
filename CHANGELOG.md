# Changelog

Ten plik dokumentuje wszystkie znaczące zmiany wprowadzone w projekcie AutoScript.

---

## v3.1 (2025-08-03) - Kompletna Dokumentacja

### Zmieniono

- **Kompletna przebudowa `README.md`**: Plik `README.md` został przepisany od podstaw, aby służyć jako jedyne, wyczerpujące źródło dokumentacji dla projektu. Dodano szczegółowe opisy filozofii projektu, architektury, przewodnika po konfiguracji, aspektów bezpieczeństwa i roadmapy.

---

## v3.0 (2025-08-03) - Architektura Modularna

### Dodano

- **Architektura oparta na komendach**: Skrypt jest teraz sterowany komendami (np. `install`, `validate`, `deploy_mastodon`, `uninstall`), co umożliwia precyzyjne zarządzanie serwerem.
- **Walidacja Konfiguracji (`validate`)**: Nowa komenda do sprawdzania poprawności pliku `autoscript.conf` przed dokonaniem jakichkolwiek zmian w systemie.
- **Mechanizm "Paragonów" (Receipts)**: Skrypt śledzi, które moduły zostały pomyślnie zainstalowane, co zapewnia inteligentne i bezpieczne ponowne uruchamianie oraz deinstalację.
- **Zaawansowane Zarządzanie Sekretami (`secrets:edit`, `secrets:view`)**: Dodano komendy-pomocniki do łatwiejszego zarządzania sekretami za pomocą `sops`.
- **Aktualizacja Skryptu (`self-update`)**: Dodano komendę do automatycznej aktualizacji skryptu z repozytorium Git.
- **Ulepszone Logowanie**: Wprowadzono kolorowe logi na konsoli (INFO, WARN, ERROR) oraz ujednolicony zapis do pliku `/var/log/autoscript.log`.
- **Przygotowano fundamenty pod przyszłe funkcje**: Stworzono puste funkcje (stubs) dla kluczowych, planowanych modułów.

### Zmieniono

- **Kompletna przebudowa `start.sh`**: Skrypt został przepisany od podstaw, aby zaimplementować nową, modularną architekturę.
- **Rozbudowa `autoscript.conf.example`**: Dodano nowe zmienne konfiguracyjne na potrzeby przyszłych modułów.

---

## v2.3 (2025-08-03) - Zmiana Domeny Głównej

### Zmieniono

- **Domyślna Struktura Domen**: Zmieniono domyślną konfigurację projektu, aby używać `social.ovh` jako domeny głównej, a usługi pomocnicze (Grafana, Prometheus) umieścić na jej subdomenach.
- Zaktualizowano wszystkie odpowiednie szablony konfiguracyjne i dokumentację, aby odzwierciedlały tę zmianę.

---

## v2.2 (2025-08-03) - Ulepszenia Dokumentacji

### Dodano

- **Instrukcja pozyskiwania kluczy**: Dodano do `README.md` nową, szczegółową sekcję "Skąd wziąć wymagane klucze?" z linkami i instrukcjami krok po kroku.

---

## v2.1 (2025-08-03) - Ulepszenia Dokumentacji

### Dodano

- **Instrukcja "Szybki Start"**: Dodano do `README.md` szczegółową sekcję, która krok po kroku prowadzi nowego użytkownika przez proces instalacji na świeżym serwerze.

---

## v2.0 (2025-08-03) - Pierwsza Duża Refaktoryzacja

### Dodano

- **Modularność Skryptu**: Wprowadzono obsługę podstawowych komend (`install`, `uninstall` itp.).
- **Idempotentność**: Skrypt zaczął sprawdzać stan systemu przed wykonaniem akcji.
- **Weryfikacja Systemu**: Skrypt zaczął weryfikować, czy jest uruchamiany na kompatybilnej dystrybucji.
- **Szablony Konfiguracji**: Konfiguracje usług zostały przeniesione do zewnętrznych plików w nowo utworzonym folderze `templates/`.
- **Opcjonalne Moduły**: Dodano możliwość włączania/wyłączania instalacji `Fail2ban`, `PostgreSQL`, `Loki` i `Restic`.

### Zmieniono

- **Struktura Projektu**: Dodano folder `templates` na pliki konfiguracyjne.

---

## v1.1 (2025-08-03) - Centralizacja Konfiguracji

### Dodano

- **Plik `CHANGELOG.md`**: Zainicjowano dziennik zmian.
- **Plik `autoscript.conf.example`**: Stworzono szablon konfiguracyjny, aby ułatwić wdrożenie.

### Zmieniono

- **Refaktoryzacja Konfiguracji**: Zastąpiono zmienne środowiskowe dedykowanym plikiem `autoscript.conf`, co znacząco uprościło zarządzanie.

---

## v1.0 (2025-08-03) - Wersja Początkowa

### Dodano

- Początkowa wersja skryptu `start.sh` do automatyzacji serwera.
- Podstawowa dokumentacja `README.md`.
- Plik `.gitattributes` do normalizacji końca linii.