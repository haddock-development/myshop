#!/bin/bash

# Cloudflare Tunnel Quick Setup Script for Bedrock WordPress
# Usage: ./tunnel.sh [start|stop|status|help]

TUNNEL_CONTAINER_NAME="cloudflare-tunnel"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

resolve_docker_bin() {
    if [ -n "${DOCKER_BIN:-}" ] && [ -x "$DOCKER_BIN" ]; then
        echo "$DOCKER_BIN"
        return
    fi

    if command -v docker >/dev/null 2>&1; then
        command -v docker
        return
    fi

    local mac_docker="/Applications/Docker.app/Contents/Resources/bin/docker"
    if [ -x "$mac_docker" ]; then
        echo "$mac_docker"
        return
    fi

    print_error "Docker CLI not found. Install Docker Desktop and ensure the CLI is available."
    exit 1
}

DOCKER_BIN=$(resolve_docker_bin)
DOCKER_DIR=$(dirname "$DOCKER_BIN")
case ":$PATH:" in
    *":$DOCKER_DIR:"*) ;;
    *) PATH="$DOCKER_DIR:$PATH" ;;
esac
DOCKER_COMPOSE_CMD="$DOCKER_BIN compose"
WPCLI_CMD="$DOCKER_COMPOSE_CMD run --rm wpcli"

ENV_FILE=".env"
ENV_BACKUP=".env.tunnel-backup"

get_env_value() {
    local key="$1"
    if [ ! -f "$ENV_FILE" ]; then
        return
    fi
    python3 - "$ENV_FILE" "$key" <<'PY_HELPER'
import sys
from pathlib import Path
path, key = sys.argv[1:3]
for line in Path(path).read_text().splitlines():
    if line.startswith(f"{key}="):
        print(line.split('=', 1)[1])
        break
PY_HELPER
}

set_env_value() {
    local key="$1"
    local value="$2"
    python3 - "$ENV_FILE" "$key" "$value" <<'PY_HELPER'
import sys
from pathlib import Path
path, key, value = sys.argv[1:4]
path_obj = Path(path)
if path_obj.exists():
    lines = path_obj.read_text().splitlines()
else:
    lines = []
for idx, line in enumerate(lines):
    if line.startswith(f"{key}="):
        lines[idx] = f"{key}={value}"
        break
else:
    lines.append(f"{key}={value}")
text = "\n".join(lines) + ("\n" if lines else "")
path_obj.write_text(text)
PY_HELPER
}

backup_env_values() {
    if [ -f "$ENV_BACKUP" ]; then
        return
    fi
    if [ -f "$ENV_FILE" ]; then
        local home=$(get_env_value "WP_HOME")
        local siteurl=$(get_env_value "WP_SITEURL")
        printf 'WP_HOME=%s\nWP_SITEURL=%s\n' "$home" "$siteurl" > "$ENV_BACKUP"
    fi
}

restore_env_values() {
    if [ -f "$ENV_BACKUP" ]; then
        while IFS='=' read -r key value; do
            [ -z "$key" ] && continue
            set_env_value "$key" "$value"
        done < "$ENV_BACKUP"
        rm -f "$ENV_BACKUP"
    else
        set_env_value "WP_HOME" "http://localhost:8080"
        set_env_value "WP_SITEURL" "http://localhost:8080/wp"
    fi
}

start_tunnel() {
    print_status "Starting Cloudflare Quick Tunnel..."
    print_status "This will create a public URL for your local WordPress site"
    print_warning "The tunnel URL will be displayed below - copy it for the next step"
    echo ""

    backup_env_values

    $DOCKER_BIN run --rm -d \
        --name $TUNNEL_CONTAINER_NAME \
        cloudflare/cloudflared:latest \
        tunnel --no-autoupdate --url http://host.docker.internal:8080

    sleep 3

    TUNNEL_URL=""
    for attempt in $(seq 1 15); do
        TUNNEL_URL=$($DOCKER_BIN logs $TUNNEL_CONTAINER_NAME 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1)
        if [ -n "$TUNNEL_URL" ]; then
            break
        fi
        sleep 2
    done

    if [ -n "$TUNNEL_URL" ]; then
        print_success "Tunnel started successfully!"
        echo ""
        echo "🌐 Tunnel URL: $TUNNEL_URL"
        echo ""

        print_status "Setting WordPress URLs to tunnel..."
        set_env_value "WP_HOME" "$TUNNEL_URL"
        set_env_value "WP_SITEURL" "$TUNNEL_URL/wp"

        $WPCLI_CMD option update home "$TUNNEL_URL" > /dev/null 2>&1
        $WPCLI_CMD option update siteurl "$TUNNEL_URL/wp" > /dev/null 2>&1

        print_success "WordPress URLs updated!"
        echo ""
        echo "🔗 Your site is now accessible at:"
        echo "   Shop:  $TUNNEL_URL"
        echo "   Admin: $TUNNEL_URL/wp/wp-admin"
        echo ""
        print_warning "Remember to run './tunnel.sh stop' when finished!"
    else
        print_error "Failed to get tunnel URL. Check Docker logs:"
        $DOCKER_BIN logs $TUNNEL_CONTAINER_NAME
        $DOCKER_BIN stop $TUNNEL_CONTAINER_NAME > /dev/null 2>&1 || true
        $DOCKER_BIN rm $TUNNEL_CONTAINER_NAME > /dev/null 2>&1 || true
        restore_env_values
    fi
}

stop_tunnel() {
    print_status "Stopping Cloudflare tunnel..."

    $DOCKER_BIN stop $TUNNEL_CONTAINER_NAME > /dev/null 2>&1

    print_status "Resetting WordPress URLs to local development..."
    restore_env_values
    local_home=$(get_env_value "WP_HOME")
    local_site=$(get_env_value "WP_SITEURL")
    local local_home_value=${local_home:-http://localhost:8080}
    local default_site=${local_home_value%/}/wp
    local local_site_value=${local_site:-$default_site}
    $WPCLI_CMD option update home "$local_home_value" > /dev/null 2>&1
    $WPCLI_CMD option update siteurl "$local_site_value" > /dev/null 2>&1

    print_success "Tunnel stopped and URLs reset to local development"
    echo ""
    echo "🏠 Your site is now accessible at:"
    echo "   Shop:  $local_home_value"
    echo "   Admin: ${local_home_value%/}/wp/wp-admin"
}

status_tunnel() {
    if $DOCKER_BIN ps | grep -q $TUNNEL_CONTAINER_NAME; then
        TUNNEL_URL=$($DOCKER_BIN logs $TUNNEL_CONTAINER_NAME 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1)
        print_success "Tunnel is running"
        echo "🌐 Tunnel URL: $TUNNEL_URL"
        echo "🔗 Shop:  $TUNNEL_URL"
        echo "🔗 Admin: $TUNNEL_URL/wp/wp-admin"
    else
        print_warning "No tunnel is currently running"
        echo "🏠 Local site: http://localhost:8080"
    fi
}

show_help() {
    echo "Cloudflare Tunnel Quick Setup for Bedrock WordPress"
    echo ""
    echo "Usage: ./tunnel.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start   - Start Cloudflare tunnel and update WordPress URLs"
    echo "  stop    - Stop tunnel and reset URLs to local development"
    echo "  status  - Show current tunnel status"
    echo "  help    - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./tunnel.sh start   # Start public tunnel"
    echo "  ./tunnel.sh stop    # Stop tunnel and go back to local"
    echo "  ./tunnel.sh status  # Check if tunnel is running"
}

case ${1:-help} in
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    status)
        status_tunnel
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
