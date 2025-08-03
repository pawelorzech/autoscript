# Changelog

## 2025-08-03

### Dodano

- **Plik `CHANGELOG.md`**: Dodano dziennik zmian w celu śledzenia rozwoju projektu.
- **Plik `autoscript.conf.example`**: Stworzono szablon konfiguracyjny, aby ułatwić użytkownikom wdrożenie.

### Zmieniono

- **Refaktoryzacja Konfiguracji**: Całkowicie zmieniono sposób konfiguracji skryptu. Zamiast polegać na zmiennych środowiskowych, skrypt wczytuje teraz wszystkie ustawienia z dedykowanego pliku `autoscript.conf`. To upraszcza zarządzanie i zmniejsza ryzyko błędu.
- **Skrypt `start.sh`**: Zaktualizowano logikę skryptu, aby wczytywał konfigurację z pliku `autoscript.conf` i sprawdzał jego obecność przed uruchomieniem.
- **Dokumentacja `README.md`**: gruntownie zaktualizowano dokumentację, aby odzwierciedlała nowy proces konfiguracji oparty na pliku. Instrukcje są teraz prostsze i bardziej przejrzyste.
