#!/bin/bash

# Named Cloudflare Tunnel Management Script for Bedrock WordPress
# Manages stable subdomain tunnels (e.g., https://dev.yourdomain.tld)
# Usage: ./named-tunnel.sh [setup|start|stop|status|set-domain|reset-local|logs|help]

DOCKER_COMPOSE_CMD="docker compose"
WPCLI_CMD="$DOCKER_COMPOSE_CMD run --rm wpcli"
TUNNEL_CONTAINER_NAME="cloudflared"
CONFIG_FILE=".tunnel-config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${CYAN}🚀 $1${NC}"
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
TUNNEL_TOKEN="$TUNNEL_TOKEN"
TUNNEL_DOMAIN="$TUNNEL_DOMAIN"
TUNNEL_NAME="$TUNNEL_NAME"
EOF
    print_success "Configuration saved to $CONFIG_FILE"
}

setup_tunnel() {
    print_header "Named Tunnel Setup"
    echo "This will set up a persistent Cloudflare Tunnel with a stable subdomain."
    echo ""

    print_status "Follow these steps in the Cloudflare Dashboard:"
    echo "1. Go to Zero Trust → Networks → Tunnels"
    echo "2. Click 'Create a tunnel' → Choose 'Cloudflared'"
    echo "3. Give your tunnel a name (e.g., 'myshop-dev')"
    echo "4. Add a Public Hostname:"
    echo "   - Hostname: dev.YOURDOMAIN.tld"
    echo "   - Service: HTTP"
    echo "   - URL: http://host.docker.internal:8080"
    echo "5. Copy the tunnel token from the 'Install and run a connector' section"
    echo ""

    # Get tunnel token
    read -p "Enter your tunnel token: " TUNNEL_TOKEN
    if [ -z "$TUNNEL_TOKEN" ]; then
        print_error "Tunnel token is required"
        exit 1
    fi

    # Get domain
    read -p "Enter your tunnel domain (e.g., dev.yourdomain.tld): " TUNNEL_DOMAIN
    if [ -z "$TUNNEL_DOMAIN" ]; then
        print_error "Domain is required"
        exit 1
    fi

    # Get tunnel name
    read -p "Enter your tunnel name (e.g., myshop-dev): " TUNNEL_NAME
    if [ -z "$TUNNEL_NAME" ]; then
        TUNNEL_NAME="myshop-dev"
    fi

    # Save configuration
    save_config

    print_success "Configuration saved!"
    echo ""
    print_status "Starting tunnel..."
    start_tunnel
}

start_tunnel() {
    load_config

    if [ -z "$TUNNEL_TOKEN" ]; then
        print_error "No tunnel configuration found. Run './named-tunnel.sh setup' first."
        exit 1
    fi

    # Check if container already exists
    if docker ps -a | grep -q "$TUNNEL_CONTAINER_NAME"; then
        print_status "Removing existing tunnel container..."
        docker rm -f "$TUNNEL_CONTAINER_NAME" > /dev/null 2>&1
    fi

    print_status "Starting named tunnel container..."

    docker run -d \
        --name "$TUNNEL_CONTAINER_NAME" \
        --restart unless-stopped \
        cloudflare/cloudflared:latest \
        tunnel --no-autoupdate run --token "$TUNNEL_TOKEN"

    if [ $? -eq 0 ]; then
        print_success "Named tunnel started successfully!"
        echo ""
        print_status "Container: $TUNNEL_CONTAINER_NAME"
        print_status "Domain: https://$TUNNEL_DOMAIN"
        echo ""
        print_warning "Now set WordPress URLs to use the tunnel domain:"
        echo "  ./named-tunnel.sh set-domain"
    else
        print_error "Failed to start tunnel container"
        exit 1
    fi
}

stop_tunnel() {
    print_status "Stopping named tunnel..."

    if docker ps | grep -q "$TUNNEL_CONTAINER_NAME"; then
        docker stop "$TUNNEL_CONTAINER_NAME" > /dev/null 2>&1
        print_success "Tunnel stopped"
    else
        print_warning "No tunnel container is running"
    fi
}

status_tunnel() {
    load_config

    if docker ps | grep -q "$TUNNEL_CONTAINER_NAME"; then
        print_success "Named tunnel is running"
        if [ ! -z "$TUNNEL_DOMAIN" ]; then
            echo "🌐 Domain: https://$TUNNEL_DOMAIN"
            echo "🔗 Shop:  https://$TUNNEL_DOMAIN"
            echo "🔗 Admin: https://$TUNNEL_DOMAIN/wp/wp-admin"
        fi
        echo "📦 Container: $TUNNEL_CONTAINER_NAME"
    else
        print_warning "Named tunnel is not running"
        echo "🏠 Local site: http://localhost:8080"
    fi
}

set_domain() {
    load_config

    if [ -z "$TUNNEL_DOMAIN" ]; then
        print_error "No domain configured. Run './named-tunnel.sh setup' first."
        exit 1
    fi

    print_status "Setting WordPress URLs to tunnel domain..."

    HTTPS_URL="https://$TUNNEL_DOMAIN"

    $WPCLI_CMD option update home "$HTTPS_URL" > /dev/null 2>&1
    $WPCLI_CMD option update siteurl "$HTTPS_URL/wp" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        print_success "WordPress URLs updated!"
        echo ""
        echo "🔗 Your site is now accessible at:"
        echo "   Shop:  $HTTPS_URL"
        echo "   Admin: $HTTPS_URL/wp/wp-admin"
        echo ""
        print_status "Flushing rewrite rules..."
        $WPCLI_CMD rewrite flush --hard > /dev/null 2>&1
        print_success "Rewrite rules flushed"
    else
        print_error "Failed to update WordPress URLs"
        exit 1
    fi
}

reset_local() {
    print_status "Resetting WordPress URLs to local development..."

    $WPCLI_CMD option update home "http://localhost:8080" > /dev/null 2>&1
    $WPCLI_CMD option update siteurl "http://localhost:8080/wp" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        print_success "URLs reset to local development"
        echo ""
        echo "🏠 Your site is now accessible at:"
        echo "   Shop:  http://localhost:8080"
        echo "   Admin: http://localhost:8080/wp/wp-admin"
        echo ""
        print_status "Flushing rewrite rules..."
        $WPCLI_CMD rewrite flush --hard > /dev/null 2>&1
        print_success "Rewrite rules flushed"
    else
        print_error "Failed to reset WordPress URLs"
        exit 1
    fi
}

show_logs() {
    if docker ps | grep -q "$TUNNEL_CONTAINER_NAME"; then
        print_status "Showing tunnel logs (Ctrl+C to exit)..."
        docker logs -f "$TUNNEL_CONTAINER_NAME"
    else
        print_error "Tunnel container is not running"
        exit 1
    fi
}

troubleshoot() {
    print_header "Troubleshooting Named Tunnel"
    echo ""

    # Check Docker
    print_status "Checking Docker status..."
    if docker ps > /dev/null 2>&1; then
        print_success "Docker is running"
    else
        print_error "Docker is not running or accessible"
        return
    fi

    # Check WordPress containers
    print_status "Checking WordPress containers..."
    if docker compose ps | grep -q "Up"; then
        print_success "WordPress containers are running"
    else
        print_warning "Some WordPress containers may not be running"
        echo "Run: docker compose up -d"
    fi

    # Check tunnel container
    print_status "Checking tunnel container..."
    if docker ps | grep -q "$TUNNEL_CONTAINER_NAME"; then
        print_success "Tunnel container is running"

        # Show recent logs
        print_status "Recent tunnel logs:"
        docker logs --tail 10 "$TUNNEL_CONTAINER_NAME"
    else
        print_warning "Tunnel container is not running"
    fi

    # Check WordPress URLs
    print_status "Checking WordPress URLs..."
    HOME_URL=$($WPCLI_CMD option get home 2>/dev/null)
    SITE_URL=$($WPCLI_CMD option get siteurl 2>/dev/null)

    if [ ! -z "$HOME_URL" ] && [ ! -z "$SITE_URL" ]; then
        echo "Home URL: $HOME_URL"
        echo "Site URL: $SITE_URL"
    else
        print_warning "Could not retrieve WordPress URLs"
    fi

    echo ""
    print_status "Common fixes:"
    echo "• Flush permalinks: ./named-tunnel.sh flush-permalinks"
    echo "• Reset to local: ./named-tunnel.sh reset-local"
    echo "• Restart tunnel: ./named-tunnel.sh stop && ./named-tunnel.sh start"
    echo "• View logs: ./named-tunnel.sh logs"
}

flush_permalinks() {
    print_status "Flushing WordPress permalinks..."
    $WPCLI_CMD rewrite flush --hard > /dev/null 2>&1
    print_success "Permalinks flushed"
}

show_help() {
    print_header "Named Cloudflare Tunnel Management"
    echo ""
    echo "Usage: ./named-tunnel.sh [command]"
    echo ""
    echo "Setup Commands:"
    echo "  setup           - Initial tunnel setup (interactive)"
    echo ""
    echo "Management Commands:"
    echo "  start           - Start the named tunnel container"
    echo "  stop            - Stop the named tunnel container"
    echo "  status          - Show tunnel status and URLs"
    echo "  logs            - Show tunnel logs (live)"
    echo ""
    echo "WordPress URL Commands:"
    echo "  set-domain      - Set WordPress URLs to tunnel domain"
    echo "  reset-local     - Reset WordPress URLs to local development"
    echo ""
    echo "Troubleshooting:"
    echo "  troubleshoot    - Run diagnostic checks"
    echo "  flush-permalinks - Flush WordPress permalink rules"
    echo ""
    echo "Examples:"
    echo "  ./named-tunnel.sh setup            # First-time setup"
    echo "  ./named-tunnel.sh start            # Start tunnel"
    echo "  ./named-tunnel.sh set-domain       # Use tunnel domain"
    echo "  ./named-tunnel.sh reset-local      # Back to localhost"
    echo ""
    echo "Configuration is stored in: $CONFIG_FILE"
}

# Main script logic
case ${1:-help} in
    setup)
        setup_tunnel
        ;;
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    status)
        status_tunnel
        ;;
    set-domain)
        set_domain
        ;;
    reset-local)
        reset_local
        ;;
    logs)
        show_logs
        ;;
    troubleshoot)
        troubleshoot
        ;;
    flush-permalinks)
        flush_permalinks
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