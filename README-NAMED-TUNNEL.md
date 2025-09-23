# Named Cloudflare Tunnel Setup (Punkt 3)

Stabile Subdomain für deine lokale WordPress-Entwicklung: **https://dev.DEINEDOMAIN.tld**

## 🎯 Ziel

Eine feste Subdomain, die dauerhaft auf dein lokales Docker-Setup zeigt, ohne dass du jedes Mal die URL wechseln musst.

## 📋 Voraussetzungen

✅ **Domain bei Cloudflare** (Nameserver auf Cloudflare)
✅ **macOS mit Docker Desktop** (läuft bereits)
✅ **WordPress Shop** läuft lokal unter http://localhost:8080
✅ **Cloudflare Account** mit Zero Trust Zugang

## 🚀 Setup-Anleitung

### Schritt 1: Tunnel im Cloudflare Dashboard anlegen

1. **Cloudflare Dashboard** öffnen und einloggen
2. **Zero Trust → Networks → Tunnels** → **"Create a tunnel"**
3. **Cloudflared** wählen, Name vergeben (z.B. `myshop-dev`)
4. **Public Hostname** hinzufügen:
   - **Hostname**: `dev.DEINEDOMAIN.tld`
   - **Service**: `HTTP`
   - **URL (Target)**: `http://host.docker.internal:8080`
5. **Speichern**
6. **Token kopieren** aus dem "Install and run a connector" Bereich

### Schritt 2: Automatisches Setup (Empfohlen)

```bash
# Interaktives Setup starten
./named-tunnel.sh setup

# Token und Domain eingeben wenn gefragt
# Tunnel wird automatisch gestartet
```

### Schritt 3: WordPress URLs setzen

```bash
# WordPress auf Tunnel-Domain umstellen
./named-tunnel.sh set-domain
```

### Schritt 4: Testen

🌐 **Shop**: https://dev.DEINEDOMAIN.tld
🔑 **Admin**: https://dev.DEINEDOMAIN.tld/wp/wp-admin

## 🛠️ Verfügbare Commands

### Script Commands

```bash
# Setup und Management
./named-tunnel.sh setup           # Einmaliges Setup (interaktiv)
./named-tunnel.sh start           # Tunnel starten
./named-tunnel.sh stop            # Tunnel stoppen
./named-tunnel.sh status          # Status anzeigen

# URL Management
./named-tunnel.sh set-domain      # WordPress auf Tunnel-Domain
./named-tunnel.sh reset-local     # WordPress auf localhost zurück

# Troubleshooting
./named-tunnel.sh logs            # Tunnel Logs anzeigen
./named-tunnel.sh troubleshoot    # Diagnose ausführen
./named-tunnel.sh flush-permalinks # Permalinks neu setzen
```

### Makefile Commands

```bash
# Named Tunnel Management
make named-tunnel-setup          # Setup (interaktiv)
make named-tunnel-start          # Tunnel starten
make named-tunnel-stop           # Tunnel stoppen
make named-tunnel-status         # Status anzeigen
make named-tunnel-domain         # WordPress auf Domain
make named-tunnel-local          # WordPress auf localhost

# Allgemeine URL Commands
make url-set URL=https://...      # URLs manuell setzen
make url-local                   # Zurück zu localhost

# Hilfe
make help                        # Alle verfügbaren Commands
```

### WordPress Utils

```bash
# Nützliche WordPress Commands
./wp-utils.sh show-urls          # Aktuelle URLs anzeigen
./wp-utils.sh flush-permalinks   # Permalinks zurücksetzen
./wp-utils.sh clear-cache        # Cache leeren
./wp-utils.sh site-health        # Site-Gesundheit prüfen
./wp-utils.sh fix-permissions    # Dateiberechtigungen reparieren
```

## 🔄 Typischer Workflow

### Setup (einmalig)
```bash
# 1. Tunnel im Cloudflare Dashboard anlegen
# 2. Script-Setup ausführen
./named-tunnel.sh setup

# 3. WordPress auf Domain umstellen
./named-tunnel.sh set-domain
```

### Tägliche Nutzung
```bash
# Tunnel starten (falls gestoppt)
./named-tunnel.sh start

# Status prüfen
./named-tunnel.sh status

# Bei Bedarf: zurück zu localhost
./named-tunnel.sh reset-local
```

## 🔧 Tunnel-Container Management

### Manueller Container-Start (Alternative)
```bash
# Container mit Token starten
docker run -d --name cloudflared --restart unless-stopped \
  cloudflare/cloudflared:latest \
  tunnel --no-autoupdate run --token <DEIN_TUNNEL_TOKEN>

# Container verwalten
docker stop cloudflared      # Stoppen
docker start cloudflared     # Starten
docker logs -f cloudflared   # Logs anzeigen
```

## 🛡️ Sicherheit & Zugang

### Öffentlichen Zugang absichern (empfohlen)

Wenn die Staging-URL nicht öffentlich sein soll:

1. **Cloudflare Zero Trust → Access**
2. **Application** für `dev.DEINEDOMAIN.tld` erstellen
3. **Policy** erstellen: nur bestimmte E-Mails/Domains zulassen
4. **E-Mail-OTP oder SSO** konfigurieren

### Starke Passwörter setzen
```bash
# Admin-Passwort ändern
./wp-utils.sh update-admin "sicheres-passwort-123"
```

## 🐛 Troubleshooting

### Häufige Probleme

**❌ 404 / Permalinks funktionieren nicht**
```bash
./named-tunnel.sh flush-permalinks
# oder im Admin: Einstellungen → Permalinks → Speichern
```

**❌ Seite lädt endlos / Redirect-Schleifen**
```bash
# URLs prüfen
./wp-utils.sh show-urls

# URLs korrigieren
./named-tunnel.sh set-domain
```

**❌ Tunnel läuft, aber 502 Error**
```bash
# Target-Port prüfen (muss host.docker.internal:8080 sein für macOS)
./named-tunnel.sh troubleshoot

# WordPress Container prüfen
docker compose ps
```

**❌ Mixed Content Warnings (HTTP/HTTPS)**
```bash
# URLs auf HTTPS prüfen
./wp-utils.sh show-urls

# Cache leeren
./wp-utils.sh clear-cache
```

### Diagnose-Commands
```bash
# Vollständige Diagnose
./named-tunnel.sh troubleshoot

# Container Status
docker compose ps

# Tunnel Logs
./named-tunnel.sh logs

# WordPress Gesundheit
./wp-utils.sh site-health
```

## 📁 Konfigurationsdateien

- **`.tunnel-config`** - Tunnel-Konfiguration (Token, Domain)
- **`tunnel-config.example`** - Beispiel-Konfiguration
- **`docker-compose.yml`** - WordPress Container Setup
- **`.env`** - WordPress Umgebungsvariablen

## 🔄 URL-Wechsel Cheat Sheet

```bash
# Zu Named Tunnel wechseln
./named-tunnel.sh set-domain

# Zu localhost wechseln
./named-tunnel.sh reset-local

# Zu beliebiger URL wechseln
make url-set URL=https://andere-domain.tld

# Aktuelle URLs anzeigen
./wp-utils.sh show-urls
```

## 🎯 Nächste Schritte

- ✅ **Named Tunnel läuft** mit stabiler Subdomain
- 🔒 **Zero Trust Access** für Passwort-Schutz einrichten
- 🎨 **Custom Domain** mit eigenem SSL-Zertifikat
- 🚀 **CI/CD Pipeline** für automatische Deployments

---

💡 **Tipp**: Nutze `./named-tunnel.sh status` um schnell zu sehen, ob dein Tunnel läuft und welche URLs aktiv sind.