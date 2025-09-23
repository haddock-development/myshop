# MyShop WordPress Stack

Modern WooCommerce-Umgebung auf Basis von Bedrock, Docker und GitHub-Automatisierung. Das Setup vereint lokale Entwicklung, öffentliche Tunnel, Zahlungsanbieter (Stripe, Google Pay) und eine optionale AP2-Agent-Schnittstelle.

## Features
- **Bedrock + WooCommerce**: Strukturierte WordPress-Installation mit Composer-abhängigem Core und Plugins.
- **Docker Desktop**: PHP-FPM, Nginx, MySQL, MailHog – Start per `docker compose up -d`.
- **Tunnel-Tooling**: Quick Tunnel (`tunnel.sh`) und Named Tunnel (`named-tunnel.sh`) für stabile Subdomains.
- **Stripe & Google Pay**: Env-basierte Konfiguration via MU-Plugin; PaymentIntents direkt aus WordPress heraus.
- **Agent Payments Protocol (AP2)**: REST-Gateway für agentengetriebene Mandate (siehe Abschnitt _AP2_).
- **Git Worktrees & CI**: Worktree-Skripte, Makefile-Shortcuts, GitHub Actions für Deployments & Releases.

## Quick Start (Local)
```bash
# Containers starten
docker compose up -d

# Shop öffnen
open http://localhost:8080
open http://localhost:8080/wp/wp-admin  # admin / admin
```

### Nützliche Make Targets
```bash
make help              # Übersicht aller Befehle
make deploy-local      # Lokalen Stack initialisieren
make status            # Docker/Deployment-Status prüfen
```

## Öffentlicher Zugriff
### Cloudflare Quick Tunnel
```bash
./tunnel.sh start   # Startet Tunnel und setzt URLs automatisch
./tunnel.sh status  # Status anzeigen
./tunnel.sh stop    # Tunnel beenden & URLs zurücksetzen
```

Alternativ: `make tunnel`, `make url-set URL=...`, `make url-local`.

### Named Tunnel (stabile Subdomain)
```bash
./named-tunnel.sh setup       # Einmaliges Setup (Token, Domain)
./named-tunnel.sh start       # Tunnel starten
./named-tunnel.sh set-domain  # WooCommerce auf Subdomain umstellen
./named-tunnel.sh reset-local # Zurück zu localhost
```

Weitere Diagnose: `./named-tunnel.sh status`, `./named-tunnel.sh logs`, `./named-tunnel.sh troubleshoot`.

## Stripe & Google Pay
Stripe ist vorinstalliert. Das MU-Plugin `web/app/mu-plugins/myshop-payment-config.php` synchronisiert Einstellungen anhand von `.env`.

Wichtige Variablen:
```
STRIPE_ENABLED=true
STRIPE_TESTMODE=true
STRIPE_TEST_PUBLISHABLE_KEY=...
STRIPE_TEST_SECRET_KEY=...
STRIPE_LIVE_PUBLISHABLE_KEY=...
STRIPE_LIVE_SECRET_KEY=...
STRIPE_TEST_WEBHOOK_SECRET=...
STRIPE_WEBHOOK_SECRET=...
STRIPE_ENABLE_GOOGLE_PAY=true
```
Optional: `STRIPE_PAYMENT_REQUEST_BUTTON_TYPE`, `STRIPE_PAYMENT_REQUEST_BUTTON_THEME`, `STRIPE_PAYMENT_REQUEST_BUTTON_LABEL`.

## AP2 – Agent Payments Protocol
Das Plugin `web/app/mu-plugins/myshop-ap2-gateway.php` stellt `POST /wp-json/myshop/ap2/v1/mandates` bereit.

- Authentifizierung über Header `X-AP2-Token` (siehe `.env`: `AP2_API_TOKEN`, `AP2_ENABLED`).
- Erwartet ein `cart_mandate`-Payload nach AP2-Spezifikation.
- Legt eine WooCommerce-Bestellung an und erstellt einen Stripe PaymentIntent; Mandat-ID wird als Metadaten gespeichert.
- Rückgabe enthält `order_id`, `mandate_id`, `payment_intent` und optional `client_secret`.

Vertiefende Notizen & offene Aufgaben: `docs/ap2-overview.md`.

_Nächste Schritte:_ Mandatsignaturen (VCs) prüfen, Rückkanal zum Agent implementieren, Push-Payments testen.

## Deployment & Worktrees
### Deployments über Make
```bash
make deploy-tunnel      # Demo via Tunnel
make deploy-staging     # GitHub Action für Staging triggern
make deploy-production  # Live-Deployment
```

### Worktrees
```bash
./worktree-manager.sh create feature/new-checkout myshop-new-checkout
./worktree-manager.sh start myshop-new-checkout
./worktree-manager.sh stop myshop-new-checkout
```

Jede Worktree-Instanz erhält eigene Ports (`docker-compose.override.yml` wird automatisch erzeugt).

## Content & Utilities
- `content-automation.sh` – Samples generieren/importieren/exportieren.
- `wp-utils.sh` – URLs prüfen, Permalinks flushen, Admin-Passwort ändern, Dev-/Prod-Mode schalten.

## Troubleshooting
```bash
./wp-utils.sh show-urls        # Aktuelle WordPress-URLs
./wp-utils.sh flush-permalinks # Permalink-Probleme fixen
docker compose ps             # Container-Status
./named-tunnel.sh troubleshoot # Tunnel-Diagnose
```

## Sicherheit
- Admin-Passwörter anpassen: `./wp-utils.sh update-admin <neues-passwort>`
- `.env` & Secrets niemals einchecken (siehe `.env.*.example` + `.gitignore`).
- Cloudflare Access oder Password Protection für öffentliche Tunnel konfigurieren.
- Stripe-Webhooks nur über HTTPS und mit Secret validieren.

## Ressourcen
- Bedrock-Dokumentation: https://roots.io/bedrock/
- AP2 Spezifikation: https://a2aprotocol.ai/ap2-protocol
- GitHub Actions Workflows: `.github/workflows/`
- Weitere Notizen & Architektur: `docs/`

---
Bei Fragen oder neuen Anforderungen gerne Issues/Tickets im Repo anlegen oder den Worktree-Workflow nutzen.
