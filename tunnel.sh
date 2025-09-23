#!/bin/bash

# Cloudflare Tunnel Quick Setup Script for Bedrock WordPress
# Usage: ./tunnel.sh [start|stop|status|help]

DOCKER_COMPOSE_CMD="docker compose"
WPCLI_CMD="$DOCKER_COMPOSE_CMD run --rm wpcli"
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

start_tunnel() {
    print_status "Starting Cloudflare Quick Tunnel..."
    print_status "This will create a public URL for your local WordPress site"
    print_warning "The tunnel URL will be displayed below - copy it for the next step"
    echo ""

    # Start tunnel in background and capture output
    docker run --rm -d \
        --name $TUNNEL_CONTAINER_NAME \
        cloudflare/cloudflared:latest \
        tunnel --no-autoupdate --url http://host.docker.internal:8080

    sleep 3

    # Get tunnel URL from logs
    TUNNEL_URL=$(docker logs $TUNNEL_CONTAINER_NAME 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1)

    if [ ! -z "$TUNNEL_URL" ]; then
        print_success "Tunnel started successfully!"
        echo ""
        echo "🌐 Tunnel URL: $TUNNEL_URL"
        echo ""
        print_status "Setting WordPress URLs to tunnel..."

        # Update WordPress URLs
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
        docker logs $TUNNEL_CONTAINER_NAME
    fi
}

stop_tunnel() {
    print_status "Stopping Cloudflare tunnel..."

    # Stop the tunnel container
    docker stop $TUNNEL_CONTAINER_NAME > /dev/null 2>&1

    # Reset WordPress URLs to local
    print_status "Resetting WordPress URLs to local development..."
    $WPCLI_CMD option update home "http://localhost:8080" > /dev/null 2>&1
    $WPCLI_CMD option update siteurl "http://localhost:8080/wp" > /dev/null 2>&1

    print_success "Tunnel stopped and URLs reset to local development"
    echo ""
    echo "🏠 Your site is now accessible at:"
    echo "   Shop:  http://localhost:8080"
    echo "   Admin: http://localhost:8080/wp/wp-admin"
}

status_tunnel() {
    if docker ps | grep -q $TUNNEL_CONTAINER_NAME; then
        TUNNEL_URL=$(docker logs $TUNNEL_CONTAINER_NAME 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1)
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

# Main script logic
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