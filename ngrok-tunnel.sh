#!/bin/bash

# ngrok Tunnel Manager
# Alternative tunnel solution with authentication and custom domains
# Usage: ./ngrok-tunnel.sh [command] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

print_header() {
    echo -e "${CYAN}🌐 $1${NC}"
}

# Configuration
NGROK_CONFIG_DIR=".ngrok-configs"
NGROK_LOG_FILE="ngrok.log"
NGROK_PID_FILE="ngrok.pid"

# Ensure config directory exists
mkdir -p "$NGROK_CONFIG_DIR"

# Check if ngrok is installed
check_ngrok_installed() {
    if ! command -v ngrok >/dev/null 2>&1; then
        print_error "ngrok not found. Installing..."
        install_ngrok
    fi
}

# Install ngrok
install_ngrok() {
    print_status "Installing ngrok..."

    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        i386) ARCH="386" ;;
    esac

    # Download ngrok
    NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-${OS}-${ARCH}.tgz"

    print_status "Downloading from: $NGROK_URL"
    curl -sSL "$NGROK_URL" | tar xz
    chmod +x ngrok

    # Move to /usr/local/bin if we can
    if sudo mv ngrok /usr/local/bin/ 2>/dev/null; then
        print_success "ngrok installed to /usr/local/bin/"
    else
        print_warning "Could not move to /usr/local/bin, keeping in current directory"
        export PATH="$PWD:$PATH"
    fi
}

# Setup ngrok authentication
setup_auth() {
    local authtoken="$1"

    if [ -z "$authtoken" ]; then
        print_error "No auth token provided"
        echo ""
        echo "📋 To get your ngrok auth token:"
        echo "1. Go to: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "2. Copy your auth token"
        echo "3. Run: ./ngrok-tunnel.sh auth <your-token>"
        return 1
    fi

    print_status "Setting up ngrok authentication..."
    ngrok authtoken "$authtoken"
    print_success "Authentication configured"
}

# Start HTTP tunnel
start_http_tunnel() {
    local port="${1:-8080}"
    local subdomain="$2"
    local config_name="${3:-default}"

    check_ngrok_installed

    # Stop any existing tunnel
    stop_tunnel

    print_header "Starting ngrok HTTP tunnel"
    print_status "Port: $port"

    # Build command
    local cmd="ngrok http $port"

    # Add subdomain if provided
    if [ -n "$subdomain" ]; then
        cmd="$cmd --subdomain=$subdomain"
        print_status "Subdomain: $subdomain"
    fi

    # Add log file
    cmd="$cmd --log=stdout"

    print_status "Starting tunnel..."

    # Start ngrok in background
    $cmd > "$NGROK_LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$NGROK_PID_FILE"

    # Wait for tunnel to establish
    print_status "Waiting for tunnel to establish..."
    sleep 5

    # Check if process is still running
    if ! kill -0 $pid 2>/dev/null; then
        print_error "ngrok failed to start"
        cat "$NGROK_LOG_FILE"
        return 1
    fi

    # Extract URL from ngrok API
    local tunnel_url
    local attempts=0
    while [ $attempts -lt 10 ]; do
        tunnel_url=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | \
                    grep -o 'https://[^"]*\.ngrok[^"]*' | head -1)

        if [ -n "$tunnel_url" ]; then
            break
        fi

        attempts=$((attempts + 1))
        sleep 2
    done

    if [ -z "$tunnel_url" ]; then
        print_error "Could not retrieve tunnel URL"
        return 1
    fi

    # Save configuration
    cat > "$NGROK_CONFIG_DIR/$config_name.conf" << EOF
TUNNEL_URL="$tunnel_url"
TUNNEL_PORT="$port"
TUNNEL_SUBDOMAIN="$subdomain"
TUNNEL_PID="$pid"
TUNNEL_TYPE="http"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

    # Update WordPress URLs if containers are running
    if $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
        print_status "Updating WordPress URLs..."
        update_wordpress_urls "$tunnel_url"
    fi

    print_success "ngrok tunnel started successfully!"
    echo ""
    echo "🌐 Public URL: $tunnel_url"
    echo "🏠 Local URL: http://localhost:$port"
    echo "📊 Dashboard: http://127.0.0.1:4040"
    echo "📝 Config: $config_name"

    # Show status
    show_status
}

# Start TCP tunnel
start_tcp_tunnel() {
    local port="${1:-3306}"
    local config_name="${2:-tcp-default}"

    check_ngrok_installed
    stop_tunnel

    print_header "Starting ngrok TCP tunnel"
    print_status "Port: $port"

    # Start ngrok TCP tunnel
    ngrok tcp "$port" --log=stdout > "$NGROK_LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$NGROK_PID_FILE"

    # Wait and get URL
    sleep 5

    if ! kill -0 $pid 2>/dev/null; then
        print_error "ngrok TCP tunnel failed to start"
        cat "$NGROK_LOG_FILE"
        return 1
    fi

    # Extract TCP URL
    local tunnel_url
    local attempts=0
    while [ $attempts -lt 10 ]; do
        tunnel_url=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null | \
                    grep -o 'tcp://[^"]*' | head -1)

        if [ -n "$tunnel_url" ]; then
            break
        fi

        attempts=$((attempts + 1))
        sleep 2
    done

    # Save configuration
    cat > "$NGROK_CONFIG_DIR/$config_name.conf" << EOF
TUNNEL_URL="$tunnel_url"
TUNNEL_PORT="$port"
TUNNEL_PID="$pid"
TUNNEL_TYPE="tcp"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

    print_success "TCP tunnel started!"
    echo "🌐 Public URL: $tunnel_url"
    echo "🏠 Local Port: $port"
}

# Update WordPress URLs
update_wordpress_urls() {
    local url="$1"

    # Update home URL
    $DOCKER_COMPOSE_CMD exec -T php wp option update home "$url" \
        --path="/var/www/html/web/wp" 2>/dev/null || true

    # Update site URL
    $DOCKER_COMPOSE_CMD exec -T php wp option update siteurl "$url/wp" \
        --path="/var/www/html/web/wp" 2>/dev/null || true

    # Flush permalinks
    $DOCKER_COMPOSE_CMD exec -T php wp rewrite flush --hard \
        --path="/var/www/html/web/wp" 2>/dev/null || true

    print_success "WordPress URLs updated"
}

# Show tunnel status
show_status() {
    if [ ! -f "$NGROK_PID_FILE" ]; then
        print_warning "No active tunnel found"
        return 1
    fi

    local pid=$(cat "$NGROK_PID_FILE")

    if ! kill -0 "$pid" 2>/dev/null; then
        print_warning "Tunnel process not running"
        rm -f "$NGROK_PID_FILE"
        return 1
    fi

    print_header "ngrok Tunnel Status"

    # Get tunnel info from API
    local tunnel_info=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || echo "{}")

    if echo "$tunnel_info" | grep -q '"public_url"'; then
        echo "$tunnel_info" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if 'tunnels' in data and len(data['tunnels']) > 0:
    tunnel = data['tunnels'][0]
    print(f\"🌐 Public URL: {tunnel.get('public_url', 'N/A')}\")
    print(f\"🏠 Local URL: {tunnel.get('config', {}).get('addr', 'N/A')}\")
    print(f\"📊 Protocol: {tunnel.get('proto', 'N/A')}\")
    print(f\"🔢 Connections: {tunnel.get('metrics', {}).get('conns', {}).get('count', 0)}\")
    print(f\"📈 Data In: {tunnel.get('metrics', {}).get('http', {}).get('count', 0)} requests\")
else:
    print('No tunnel information available')
" 2>/dev/null || echo "Tunnel is running but API not accessible"
    else
        print_warning "Tunnel API not responding"
    fi

    echo "📊 Dashboard: http://127.0.0.1:4040"
    echo "🔍 PID: $pid"

    # Show recent logs
    if [ -f "$NGROK_LOG_FILE" ]; then
        echo ""
        echo "📝 Recent logs:"
        tail -5 "$NGROK_LOG_FILE" | sed 's/^/   /'
    fi
}

# Stop tunnel
stop_tunnel() {
    if [ -f "$NGROK_PID_FILE" ]; then
        local pid=$(cat "$NGROK_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_status "Stopping ngrok tunnel (PID: $pid)..."
            kill "$pid" 2>/dev/null || true
            sleep 2

            # Force kill if still running
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$NGROK_PID_FILE"
    fi

    # Clean up log file
    rm -f "$NGROK_LOG_FILE"

    print_success "Tunnel stopped"
}

# List saved configurations
list_configs() {
    print_header "Saved ngrok Configurations"

    if [ ! -d "$NGROK_CONFIG_DIR" ] || [ -z "$(ls -A "$NGROK_CONFIG_DIR" 2>/dev/null)" ]; then
        print_warning "No saved configurations found"
        return
    fi

    for config in "$NGROK_CONFIG_DIR"/*.conf; do
        if [ -f "$config" ]; then
            local name=$(basename "$config" .conf)
            source "$config"

            echo ""
            echo "📁 Config: $name"
            echo "   URL: ${TUNNEL_URL:-N/A}"
            echo "   Port: ${TUNNEL_PORT:-N/A}"
            echo "   Type: ${TUNNEL_TYPE:-http}"
            echo "   Created: ${CREATED_AT:-N/A}"
        fi
    done
}

# Load saved configuration
load_config() {
    local config_name="$1"

    if [ -z "$config_name" ]; then
        print_error "No configuration name provided"
        echo "Available configs:"
        list_configs
        return 1
    fi

    local config_file="$NGROK_CONFIG_DIR/$config_name.conf"

    if [ ! -f "$config_file" ]; then
        print_error "Configuration not found: $config_name"
        return 1
    fi

    source "$config_file"

    print_status "Loaded configuration: $config_name"

    # Start tunnel based on saved config
    if [ "$TUNNEL_TYPE" = "tcp" ]; then
        start_tcp_tunnel "$TUNNEL_PORT" "$config_name"
    else
        start_http_tunnel "$TUNNEL_PORT" "$TUNNEL_SUBDOMAIN" "$config_name"
    fi
}

# Quick setup for common scenarios
quick_setup() {
    local scenario="$1"

    case "$scenario" in
        "wordpress")
            print_header "Quick WordPress Setup"

            # Ensure WordPress is running
            if ! $DOCKER_COMPOSE_CMD ps | grep -q "Up"; then
                print_status "Starting WordPress containers..."
                $DOCKER_COMPOSE_CMD up -d
                sleep 15
            fi

            start_http_tunnel 8080 "" "wordpress"
            ;;
        "database")
            print_header "Quick Database Access Setup"
            start_tcp_tunnel 3306 "database"
            ;;
        "dev")
            print_header "Quick Development Setup"
            start_http_tunnel 8080 "dev-$(whoami)" "development"
            ;;
        *)
            print_error "Unknown scenario: $scenario"
            echo "Available scenarios: wordpress, database, dev"
            ;;
    esac
}

# Show ngrok dashboard
show_dashboard() {
    if [ -f "$NGROK_PID_FILE" ]; then
        local pid=$(cat "$NGROK_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_success "Opening ngrok dashboard..."

            # Try to open browser (macOS/Linux)
            if command -v open >/dev/null 2>&1; then
                open http://127.0.0.1:4040
            elif command -v xdg-open >/dev/null 2>&1; then
                xdg-open http://127.0.0.1:4040
            else
                echo "🌐 Dashboard URL: http://127.0.0.1:4040"
            fi
        else
            print_error "No active tunnel found"
        fi
    else
        print_error "No tunnel running"
    fi
}

# Show help
show_help() {
    print_header "ngrok Tunnel Manager"
    echo ""
    echo "Usage: ./ngrok-tunnel.sh [command] [options]"
    echo ""
    echo "Authentication:"
    echo "  auth <token>         - Set up ngrok authentication token"
    echo ""
    echo "HTTP Tunnels:"
    echo "  start [port] [subdomain] [name] - Start HTTP tunnel (default port: 8080)"
    echo "  quick-setup <scenario>          - Quick setup for common scenarios"
    echo "                                   Scenarios: wordpress, database, dev"
    echo ""
    echo "TCP Tunnels:"
    echo "  tcp <port> [name]    - Start TCP tunnel"
    echo ""
    echo "Management:"
    echo "  status               - Show tunnel status and metrics"
    echo "  stop                 - Stop active tunnel"
    echo "  dashboard            - Open ngrok web dashboard"
    echo ""
    echo "Configuration:"
    echo "  configs              - List saved configurations"
    echo "  load <name>          - Load and start saved configuration"
    echo ""
    echo "Examples:"
    echo "  ./ngrok-tunnel.sh auth abc123def456..."
    echo "  ./ngrok-tunnel.sh start 8080"
    echo "  ./ngrok-tunnel.sh start 8080 my-app production"
    echo "  ./ngrok-tunnel.sh tcp 3306"
    echo "  ./ngrok-tunnel.sh quick-setup wordpress"
    echo ""
    echo "🌐 **Features:**"
    echo "   - HTTP/HTTPS and TCP tunnels"
    echo "   - Custom subdomains (paid plan)"
    echo "   - Real-time traffic inspection"
    echo "   - Configuration management"
    echo "   - WordPress URL auto-update"
    echo ""
    echo "📚 **Get started:** Sign up at https://ngrok.com/"
}

# Main script logic
case ${1:-help} in
    auth)
        setup_auth "$2"
        ;;
    start)
        start_http_tunnel "$2" "$3" "$4"
        ;;
    tcp)
        start_tcp_tunnel "$2" "$3"
        ;;
    status)
        show_status
        ;;
    stop)
        stop_tunnel
        ;;
    configs)
        list_configs
        ;;
    load)
        load_config "$2"
        ;;
    quick-setup)
        quick_setup "$2"
        ;;
    dashboard)
        show_dashboard
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
