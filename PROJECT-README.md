# Bedrock WordPress + Cloudflare Tunnel Development Setup

Vollständige lokale WordPress-Entwicklungsumgebung mit öffentlichen Tunnel-Optionen.

## 🎯 Was ist eingerichtet?

✅ **Bedrock WordPress** mit moderner Projektstruktur
✅ **Docker-Umgebung** (PHP 8.2, Nginx, MySQL, MailHog)
✅ **WooCommerce** für E-Commerce Funktionalität
✅ **Quick Tunnels** für temporäre öffentliche URLs
✅ **Named Tunnels** für stabile Subdomains
✅ **Umfangreiches Tooling** für Development & Troubleshooting

## 🚀 Quick Start

### Lokale Entwicklung
```bash
# WordPress lokal starten
docker compose up -d

# Site öffnen
open http://localhost:8080
open http://localhost:8080/wp/wp-admin  # admin/admin
```

### Öffentlicher Zugang (temporär)
```bash
# Quick Tunnel starten
./tunnel.sh start

# Tunnel stoppen
./tunnel.sh stop
```

### Stabile Subdomain
```bash
# Einmaliges Setup
./named-tunnel.sh setup

# Tunnel verwenden
./named-tunnel.sh start
./named-tunnel.sh set-domain
```

## 📁 Projektstruktur

```
myshop/
├── web/                    # WordPress Web Root
│   ├── wp/                # WordPress Core
│   ├── app/               # Plugins, Themes, Uploads
│   └── index.php          # WordPress Entry Point
├── vendor/                # Composer Dependencies
├── config/                # WordPress Configuration
├── .docker/               # Docker Configuration
│   ├── php/               # PHP Container Config
│   └── nginx/             # Nginx Configuration
├── tunnel.sh              # Quick Tunnel Script
├── named-tunnel.sh        # Named Tunnel Script
├── wp-utils.sh            # WordPress Utilities
├── Makefile              # Command Shortcuts
├── docker-compose.yml    # Docker Services
├── .env                  # Environment Configuration
└── README-*.md           # Detailed Documentation
```

## 🛠️ Verfügbare Commands

### Docker & WordPress
```bash
docker compose up -d        # Start WordPress
docker compose down         # Stop WordPress
docker compose ps           # Show container status
```

### Quick Tunnels (temporäre URLs)
```bash
./tunnel.sh start          # Start + auto-configure URLs
./tunnel.sh stop           # Stop + reset to localhost
./tunnel.sh status         # Show current status

# Alternative: Makefile
make tunnel                # Start tunnel (manual URL setup)
make url-set URL=...       # Set WordPress URLs
make url-local             # Reset to localhost
```

### Named Tunnels (stabile Subdomains)
```bash
./named-tunnel.sh setup           # One-time setup
./named-tunnel.sh start           # Start tunnel container
./named-tunnel.sh set-domain      # Use tunnel domain
./named-tunnel.sh reset-local     # Back to localhost
./named-tunnel.sh status          # Show status
./named-tunnel.sh troubleshoot    # Diagnose issues

# Alternative: Makefile
make named-tunnel-setup    # Setup tunnel
make named-tunnel-start    # Start tunnel
make named-tunnel-domain   # Use domain
make named-tunnel-local    # Back to localhost
```

### WordPress Utilities
```bash
./wp-utils.sh show-urls          # Current WordPress URLs
./wp-utils.sh flush-permalinks   # Fix permalink issues
./wp-utils.sh clear-cache        # Clear WordPress cache
./wp-utils.sh site-health        # Health check
./wp-utils.sh update-admin <pw>  # Change admin password
./wp-utils.sh dev-mode           # Enable debug mode
./wp-utils.sh prod-mode          # Disable debug mode
```

### Help & Info
```bash
make help                  # All available make commands
./tunnel.sh help          # Quick tunnel help
./named-tunnel.sh help    # Named tunnel help
./wp-utils.sh help        # WordPress utilities help
```

## 🌐 Zugangspunkte

### Lokal
- **Shop**: http://localhost:8080
- **Admin**: http://localhost:8080/wp/wp-admin (admin/admin)
- **Mail**: http://localhost:8025 (MailHog)
- **Database**: localhost:3306 (wordpress/wordpress)

### Quick Tunnel (temporär)
- **Shop**: https://random123.trycloudflare.com
- **Admin**: https://random123.trycloudflare.com/wp/wp-admin

### Named Tunnel (stabil)
- **Shop**: https://dev.yourdomain.tld
- **Admin**: https://dev.yourdomain.tld/wp/wp-admin

## 📚 Detaillierte Dokumentation

- **[README-TUNNEL.md](README-TUNNEL.md)** - Quick Tunnel Setup & Nutzung
- **[README-NAMED-TUNNEL.md](README-NAMED-TUNNEL.md)** - Named Tunnel Setup & Konfiguration

## 🔧 Konfigurationsdateien

- **`.env`** - WordPress Umgebung (DB, URLs, etc.)
- **`docker-compose.yml`** - Docker Services
- **`.tunnel-config`** - Named Tunnel Konfiguration (wird beim Setup erstellt)
- **`tunnel-config.example`** - Beispiel für Tunnel-Konfiguration

## 🔄 Typische Workflows

### Lokale Entwicklung
1. `docker compose up -d` - WordPress starten
2. Entwickeln auf http://localhost:8080
3. `docker compose down` - Stoppen wenn fertig

### Quick Demo/Test
1. `./tunnel.sh start` - Öffentliche URL erstellen
2. URL teilen für Tests/Reviews
3. `./tunnel.sh stop` - Tunnel beenden

### Stabile Staging-Umgebung
1. `./named-tunnel.sh setup` - Einmalig: Tunnel konfigurieren
2. `./named-tunnel.sh start` - Tunnel starten
3. `./named-tunnel.sh set-domain` - WordPress auf Domain umstellen
4. Entwickeln mit stabiler URL
5. `./named-tunnel.sh reset-local` - Zurück zu localhost

## 🐛 Troubleshooting

### WordPress-Probleme
```bash
./wp-utils.sh site-health      # Gesundheitscheck
./wp-utils.sh flush-permalinks # Permalink-Probleme
./wp-utils.sh show-urls        # Aktuelle URLs prüfen
```

### Tunnel-Probleme
```bash
./named-tunnel.sh troubleshoot # Vollständige Diagnose
./named-tunnel.sh logs         # Tunnel Logs
docker compose ps              # Container Status
```

### Container-Probleme
```bash
docker compose down && docker compose up -d  # Neustart
docker compose logs                          # Alle Logs
docker system prune                          # Docker aufräumen
```

## 🛡️ Sicherheit

### Lokale Entwicklung
- Ändere Admin-Passwort: `./wp-utils.sh update-admin neues-passwort`
- Debug-Modus aktivieren: `./wp-utils.sh dev-mode`

### Öffentliche Tunnels
- **Starke Passwörter** verwenden

## 🧭 GitHub & Worktree-Flow

### GitHub Remote verbinden
1. Repository in GitHub anlegen (leer, ohne README).  
2. Im Projekt ausführen:
   ```bash
   ./bin/setup-github.sh origin https://github.com/<account>/<repo>.git
   ```
   Der Helper fügt den Remote hinzu, holt Refs und pusht den aktuellen Branch.
3. Secrets für Workflows setzen (Repo → Settings → Secrets & variables → Actions):
   - `CLOUDFLARE_TUNNEL_TOKEN` *(optional, falls du Named Tunnels in CI nutzen willst)*
   - `CF_API_TOKEN` / `CF_ACCOUNT_ID` nur nötig, wenn du später automatisierte Deployments zu Cloudflare anstößt.

### GitHub Actions
- `.github/workflows/ci.yml` lintet Composer + Laravel Pint auf jedem Push und Pull Request.  
  👉 Voraussetzung: `composer install` muss laufen – falls neue Dev-Abhängigkeiten hinzukommen, `composer update` + `composer.lock` committen.
- `.github/workflows/tunnel-preview.yml` baut eine vollständige Preview-Instanz (Docker + Cloudflare Quick Tunnel).  
  👉 Der Workflow aktiviert automatisch das Theme `myshop-theme`.

### Worktrees nutzen
Die mitgelieferte `worktree-manager.sh` automatisiert parallele Branch-Umgebungen:

```bash
./worktree-manager.sh create feature/awesome awesome-demo   # legt neuen Worktree an
./worktree-manager.sh list                                  # Überblick
./worktree-manager.sh start awesome-demo                    # startet Docker + Tunnel
```

> Hinweis: Das Script warnt, falls kein Git-Remote vorhanden ist. Richte vor der kollaborativen Arbeit unbedingt `origin` ein (siehe oben), damit Worktree-Branches sauber gepusht werden können.

Für CI/Preview ist es sinnvoll, Branches über Worktrees zu verwalten – du kannst gleichzeitig mehrere Demos laufen lassen (z. B. `myshop-main`, `myshop-feature-x`).
- **Tunnel nur bei Bedarf** aktivieren
- **URLs nach Tests zurücksetzen**
- **Cloudflare Access** für geschützte Bereiche

## 🚀 Nächste Schritte

- **Custom Theme/Plugin Entwicklung** in `web/app/`
- **CI/CD Pipeline** für automatische Deployments
- **SSL-Zertifikate** für eigene Domains
- **Backup-Strategie** für Production

---

💡 **Tipp**: Nutze `make help` für eine schnelle Übersicht aller verfügbaren Commands!

🔗 **Support**: Bei Problemen siehe die detaillierten README-Dateien oder nutze die Troubleshooting-Scripts.
