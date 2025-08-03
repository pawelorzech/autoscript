# Changelog

## 2025-08-03 (v3.0) - Architektura modularna

### Dodano

- **Architektura oparta na komendach**: Skrypt jest teraz sterowany komendami (np. `install`, `validate`, `deploy_mastodon`, `uninstall`), co umożliwia precyzyjne zarządzanie serwerem.
- **Walidacja Konfiguracji (`validate`)**: Nowa komenda do sprawdzania poprawności pliku `autoscript.conf` przed dokonaniem jakichkolwiek zmian w systemie.
- **Mechanizm "Paragonów" (Receipts)**: Skrypt śledzi, które moduły zostały pomyślnie zainstalowane, co zapewnia inteligentne i bezpieczne ponowne uruchamianie oraz deinstalację.
- **Zaawansowane Zarządzanie Sekretami (`secrets:edit`, `secrets:view`)**: Dodano komendy-pomocniki do łatwiejszego zarządzania sekretami za pomocą `sops`.
- **Aktualizacja Skryptu (`self-update`)**: Dodano komendę do automatycznej aktualizacji skryptu z repozytorium Git.
- **Ulepszone Logowanie**: Wprowadzono kolorowe logi na konsoli (INFO, WARN, ERROR) oraz ujednolicony zapis do pliku `/var/log/autoscript.log`.
- **Przygotowano fundamenty pod przyszłe funkcje**: Stworzono puste funkcje (stubs) dla:
  - Wdrożenia Mastodona (`deploy_mastodon`).
  - Dynamicznego odkrywania usług przez Prometheus.
  - Centralnego logowania dla hosta z Promtail.
  - Interaktywnej konfiguracji.
  - Wzmocnienia bezpieczeństwa kontenerów (AppArmor).
  - Zaawansowanych kopii zapasowych (`backup:run`, `backup:restore`).

### Zmieniono

- **Kompletna przebudowa `start.sh`**: Skrypt został przepisany od podstaw, aby zaimplementować nową, modularną architekturę.
- **Rozbudowa `autoscript.conf.example`**: Dodano nowe zmienne konfiguracyjne na potrzeby przyszłych modułów.
- **Dokumentacja**: `README.md` zostało całkowicie przepisane, aby szczegółowo opisać nową architekturę, komendy i zaawansowane koncepcje.

---

(Poprzednie wersje poniżej)
