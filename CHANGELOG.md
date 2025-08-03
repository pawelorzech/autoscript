# Changelog

## v4.0 (2025-08-03) - Pełna Implementacja Funkcji

### Dodano

- **Pełna implementacja `deploy_mastodon`**: Komenda teraz w pełni automatyzuje wdrożenie Mastodona, włącznie z generowaniem sekretów, konfiguracji i migracjami bazy danych.
- **Dynamiczne odkrywanie usług Prometheus**: Prometheus został skonfigurowany do automatycznego monitorowania kontenerów na podstawie etykiet Docker, co eliminuje potrzebę ręcznej edycji konfiguracji.
- **Centralne logowanie dla hosta**: Promtail został skonfigurowany do zbierania logów nie tylko z kontenerów, ale również z kluczowych plików systemowych (`/var/log`), co daje pełny obraz zdarzeń w systemie.
- **Zaimplementowano puste funkcje (stubs)** dla `interactive-setup`, `backup:*` i `self-update`, przygotowując grunt pod ich przyszłą, pełną implementację.

### Zmieniono

- **Struktura Monitoringu**: Przebudowano konfigurację `prometheus.yml` i `docker-compose.yml` w folderze `templates/monitoring`, aby wspierać dynamiczne odkrywanie usług.
- **Struktura Projektu**: Dodano folder `templates/mastodon` z szablonami dla `docker-compose.yml` i `.env.production`.

(Poprzednie wersje poniżej)
