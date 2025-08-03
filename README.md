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

## 4. Użycie

### Krok 1: Konfiguracja

1.  Sklonuj repozytorium na serwer: `git clone ...`
2.  Przejdź do folderu: `cd autoscript`
3.  Stwórz plik konfiguracyjny z szablonu: `cp autoscript.conf.example autoscript.conf`
4.  Otwórz `autoscript.conf` i **dokładnie wypełnij wszystkie zmienne**, zwłaszcza te w sekcji `WYMAGANE`.

### Krok 2: Uruchomienie Skryptu

Skryptem zarządza się za pomocą komend. Wszystkie komendy należy wykonywać z uprawnieniami `root` (np. `sudo ./start.sh <komenda>`).

**Główne Komendy:**

- `sudo ./start.sh install`
  **Pełna, pierwsza instalacja.** Wykonuje wszystkie niezbędne kroki: instaluje pakiety, konfiguruje zabezpieczenia, wdraża Dockera, Traefika i stos monitoringu. Uruchom tę komendę na nowym serwerze.

- `sudo ./start.sh uninstall`
  **Pełna deinstalacja.** Zatrzymuje i usuwa wszystkie usługi, kontenery, wolumeny, a także odinstalowuje pakiety i wycofuje zmiany konfiguracyjne. **Używaj z ostrożnością!**

**Komendy do Zarządzania Modułami:**

Możesz zarządzać poszczególnymi częściami systemu niezależnie.

- `sudo ./start.sh deploy_traefik`
- `sudo ./start.sh deploy_monitoring`
- `sudo ./start.sh deploy_database` (jeśli włączone w konfigu)

**Komendy Pomocnicze:**

- `sudo ./start.sh reboot` - Bezpieczny restart serwera.
- `sudo ./start.sh update` - Aktualizacja pakietów systemowych.

## 5. Opis Modułów Opcjonalnych

Możesz włączyć je w pliku `autoscript.conf`.

- **Fail2ban**: Dodatkowa ochrona, która analizuje logi i blokuje adresy IP wykazujące złośliwą aktywność (np. próby logowania brute-force).
- **PostgreSQL**: Wdraża kontener z popularną bazą danych. Hasło jest zarządzane przez `sops`.
- **Loki**: System do agregacji logów z Twoich kontenerów. Umożliwia ich wygodne przeszukiwanie w Grafanie.
- **Restic Backup**: Instaluje i konfiguruje `restic` do tworzenia regularnych, szyfrowanych kopii zapasowych do chmury (np. AWS S3, Backblaze B2). **Wymaga dodatkowej konfiguracji po stronie dostawcy chmury!**

## 6. Co robić po instalacji?

Po zakończeniu komendy `install`:

1.  **Nowy Port SSH:** Został zmieniony na losowy. Znajdziesz go w pliku `/root/ssh_port.txt`.
2.  **Logowanie**: Logowanie na `root` jest zablokowane. Użyj użytkownika `admin` z Twoim kluczem SSH i nowym portem: `ssh admin@<IP> -p <PORT>`.
3.  **TOTP (2FA)**: Przy pierwszym użyciu `sudo` zostaniesz poproszony o skonfigurowanie aplikacji do uwierzytelniania (np. Google Authenticator).
4.  **Dostęp do usług**: Usługi będą dostępne pod subdomenami Twojej domeny (np. `https://grafana.twojadomena.pl`).
