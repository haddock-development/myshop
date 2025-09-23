# Cloudflare Tunnel Setup für Bedrock WordPress

Dieses Setup ermöglicht es dir, deine lokale WordPress-Entwicklungsumgebung über einen öffentlichen Cloudflare Tunnel zugänglich zu machen.

## 🚀 Quick Start

### Option 1: Automatisches Script (Empfohlen)

```bash
# Tunnel starten (automatisch URLs setzen)
./tunnel.sh start

# Status prüfen
./tunnel.sh status

# Tunnel stoppen (URLs zurücksetzen)
./tunnel.sh stop
```

### Option 2: Makefile Commands

```bash
# Tunnel starten
make tunnel

# URLs manuell setzen (nach Kopieren der Tunnel-URL)
make url-set URL=https://abc12345.trycloudflare.com

# URLs auf lokal zurücksetzen
make url-local
```

### Option 3: Manuelle Docker Commands

```bash
# Tunnel starten
docker run --rm -it cloudflare/cloudflared:latest \
  tunnel --no-autoupdate --url http://host.docker.internal:8080

# WordPress URLs setzen (URL aus Tunnel-Output kopieren)
docker compose run --rm wpcli option update home 'https://abc12345.trycloudflare.com'
docker compose run --rm wpcli option update siteurl 'https://abc12345.trycloudflare.com/wp'

# URLs zurücksetzen
docker compose run --rm wpcli option update home 'http://localhost:8080'
docker compose run --rm wpcli option update siteurl 'http://localhost:8080/wp'
```

## 📋 Workflow

1. **Lokale Entwicklung starten**
   ```bash
   docker compose up -d
   ```

2. **Tunnel für öffentlichen Zugang starten**
   ```bash
   ./tunnel.sh start
   ```

3. **Entwickeln und testen**
   - Nutze die angezeigte Tunnel-URL
   - Teile die URL mit Team/Kunden für Tests

4. **Tunnel beenden**
   ```bash
   ./tunnel.sh stop
   ```

## 🔧 Verfügbare Commands

### Script Commands (`./tunnel.sh`)
- `start` - Startet Tunnel und setzt WordPress URLs automatisch
- `stop` - Stoppt Tunnel und setzt URLs auf lokal zurück
- `status` - Zeigt aktuellen Tunnel-Status
- `help` - Zeigt Hilfe an

### Makefile Commands
- `make tunnel` - Startet Tunnel (manuelles URL setzen nötig)
- `make url-set URL=<tunnel-url>` - Setzt WordPress URLs auf Tunnel
- `make url-local` - Setzt URLs auf lokale Entwicklung zurück
- `make help` - Zeigt verfügbare Commands

## ⚠️ Wichtige Hinweise

### Sicherheit
- Quick Tunnels sind **öffentlich zugänglich**
- Nutze **starke Admin-Passwörter** (aktuell: admin/admin)
- Teile Tunnel-URLs nur mit vertrauenswürdigen Personen
- Stoppe Tunnel wenn nicht benötigt

### URLs und Caching
- WordPress URLs werden automatisch auf Tunnel umgestellt
- Browser-Cache leeren nach URL-Wechsel
- **Immer URLs zurücksetzen** nach Tunnel-Nutzung

### Fehlerbehandlung

**Tunnel startet nicht:**
```bash
# Prüfe ob Docker läuft
docker ps

# Prüfe WordPress Container
docker compose ps
```

**URLs funktionieren nicht:**
```bash
# URLs manuell prüfen
docker compose run --rm wpcli option get home
docker compose run --rm wpcli option get siteurl

# URLs manuell setzen
./tunnel.sh stop  # Setzt auf lokal zurück
```

## 🔄 Nützliche Commands

```bash
# Docker Container Status
docker compose ps

# WordPress Cache leeren
docker compose run --rm wpcli cache flush

# Aktuelle WordPress URLs anzeigen
docker compose run --rm wpcli option get home
docker compose run --rm wpcli option get siteurl

# Tunnel Logs anzeigen
docker logs cloudflare-tunnel
```

## 📝 Nächste Schritte

Für produktive Nutzung:
- **Named Tunnel** mit stabiler Subdomain einrichten
- **Cloudflare Access** für Passwort-Schutz
- **SSL-Zertifikate** für eigene Domain

---

💡 **Tipp:** Nutze `./tunnel.sh start` für schnelle Tests und `./tunnel.sh stop` um sauber zur lokalen Entwicklung zurückzukehren.