# Changelog

## 2025-08-03 (v2.1)

### Dodano

- **Instrukcja "Szybki Start"**: Dodano do `README.md` szczegółową sekcję, która krok po kroku prowadzi nowego użytkownika przez proces instalacji na świeżym serwerze Debian/Ubuntu.

### Zmieniono

- Poprawiono przejrzystość i strukturę dokumentacji `README.md`.

---

## 2025-08-03 (v2.0)

### Dodano

- **Modularność Skryptu**: Wprowadzono obsługę komend (`install`, `deploy_traefik`, `deploy_monitoring`, `uninstall`), co pozwala na uruchamianie tylko wybranych części skryptu.
- **Idempotentność**: Skrypt sprawdza stan systemu (np. czy użytkownik istnieje) przed wykonaniem akcji, co pozwala na jego bezpieczne wielokrotne uruchamianie.
- **Weryfikacja Systemu**: Skrypt weryfikuje, czy jest uruchamiany na kompatybilnej dystrybucji (Debian/Ubuntu).
- **Ulepszone Logowanie**: Wszystkie operacje są logowane do pliku `/var/log/autoscript.log`.
- **Funkcja `uninstall`**: Dodano możliwość bezpiecznego odinstalowania wszystkich komponentów wdrożonych przez skrypt.
- **Szablony Konfiguracji**: Konfiguracje usług (Traefik, Prometheus) zostały przeniesione do zewnętrznych plików w folderze `templates/`.
- **Opcjonalne Moduły** (konfigurowalne w `autoscript.conf`):
  - **Fail2ban**: Dodatkowa warstwa ochrony przed atakami brute-force.
  - **PostgreSQL**: Możliwość wdrożenia bazy danych.
  - **Loki**: Centralne zbieranie logów z kontenerów Docker.
  - **Restic Backups**: Integracja z systemem kopii zapasowych (wymaga ręcznej konfiguracji po stronie dostawcy chmury).

### Zmieniono

- **Struktura Projektu**: Dodano folder `templates` na pliki konfiguracyjne.
- **Plik Konfiguracyjny**: `autoscript.conf.example` został rozbudowany o nowe opcje dla modułów opcjonalnych.
- **Dokumentacja**: `README.md` zostało całkowicie przepisane, aby odzwierciedlać nową, modularną strukturę i wszystkie nowe funkcje.

---

## 2025-08-03 (v1.1)

### Dodano

- **Plik `CHANGELOG.md`**: Dodano dziennik zmian w celu śledzenia rozwoju projektu.
- **Plik `autoscript.conf.example`**: Stworzono szablon konfiguracyjny, aby ułatwić użytkownikom wdrożenie.

### Zmieniono

- **Refaktoryzacja Konfiguracji**: Całkowicie zmieniono sposób konfiguracji skryptu. Zamiast polegać na zmiennych środowiskowych, skrypt wczytuje teraz wszystkie ustawienia z dedykowanego pliku `autoscript.conf`. To upraszcza zarządzanie i zmniejsza ryzyko błędu.
- **Skrypt `start.sh`**: Zaktualizowano logikę skryptu, aby wczytywał konfigurację z pliku `autoscript.conf` i sprawdzał jego obecność przed uruchomieniem.
- **Dokumentacja `README.md`**: gruntownie zaktualizowano dokumentację, aby odzwierciedlała nowy proces konfiguracji oparty na pliku. Instrukcje są teraz prostsze i bardziej przejrzyste.