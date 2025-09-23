#!/bin/bash

# Advanced Tunnel Manager für Bedrock WordPress
# Unterstützt: Quick Tunnels, Named Tunnels, Multiple Environments, Git Worktrees
# Usage: ./tunnel-manager.sh [command] [options]

CONFIG_DIR=".tunnel-configs"
DEFAULT_CONFIG="$CONFIG_DIR/default.conf"
WORKTREE_CONFIG="$CONFIG_DIR/$(basename $(pwd)).conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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

print_header() {
    echo -e "${CYAN}🚀 $1${NC}"
}

print_env() {
    echo -e "${PURPLE}🌍 $1${NC}"
}

# Initialize config directory
init_configs() {
    mkdir -p "$CONFIG_DIR"

    # Create default config if it doesn't exist
    if [ ! -f "$DEFAULT_CONFIG" ]; then
        cat > "$DEFAULT_CONFIG" << 'EOF'
# Default Tunnel Configuration
ENVIRONMENT="development"
LOCAL_PORT="8080"
TUNNEL_TYPE="quick"
TUNNEL_TOKEN=""
TUNNEL_DOMAIN=""
TUNNEL_NAME=""
AUTO_SET_URLS="true"
WP_DEBUG="true"
EOF
        print_success "Created default configuration"
    fi
}

# Load configuration for current worktree/environment
load_config() {
    local config_file="$DEFAULT_CONFIG"

    # Use worktree-specific config if it exists
    if [ -f "$WORKTREE_CONFIG" ]; then
        config_file="$WORKTREE_CONFIG"
        print_status "Using worktree config: $(basename $(pwd))"
    fi

    if [ -f "$config_file" ]; then
        source "$config_file"
        return 0
    else
        print_error "No configuration found. Run 'init-env' first."
        return 1
    fi
}

# Save configuration
save_config() {
    local config_file="${1:-$DEFAULT_CONFIG}"

    cat > "$config_file" << EOF
# Tunnel Configuration for $(basename $(pwd))
ENVIRONMENT="$ENVIRONMENT"
LOCAL_PORT="$LOCAL_PORT"
TUNNEL_TYPE="$TUNNEL_TYPE"
TUNNEL_TOKEN="$TUNNEL_TOKEN"
TUNNEL_DOMAIN="$TUNNEL_DOMAIN"
TUNNEL_NAME="$TUNNEL_NAME"
AUTO_SET_URLS="$AUTO_SET_URLS"
WP_DEBUG="$WP_DEBUG"
# Created: $(date)
EOF
    print_success "Configuration saved to $config_file"
}

# Initialize environment
init_env() {
    print_header "Environment Setup"

    local current_dir=$(basename $(pwd))
    local is_worktree="false"

    # Detect if we're in a worktree
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local git_dir=$(git rev-parse --git-common-dir)
        if [[ "$git_dir" == *"worktrees"* ]]; then
            is_worktree="true"
            print_env "Detected Git Worktree: $current_dir"
        fi
    fi

    echo "Setting up tunnel configuration for: $current_dir"
    echo ""

    # Environment selection
    echo "Select environment:"
    echo "1) Development (dev.domain.tld)"
    echo "2) Staging (staging.domain.tld)"
    echo "3) Feature branch (feature-name.domain.tld)"
    echo "4) Custom"
    read -p "Choose [1-4]: " env_choice

    case $env_choice in
        1) ENVIRONMENT="development" ;;
        2) ENVIRONMENT="staging" ;;
        3) ENVIRONMENT="feature" ;;
        4)
            read -p "Enter environment name: " ENVIRONMENT
            ;;
        *) ENVIRONMENT="development" ;;
    esac

    # Tunnel type
    echo ""
    echo "Select tunnel type:"
    echo "1) Quick Tunnel (temporary URL)"
    echo "2) Named Tunnel (stable subdomain)"
    read -p "Choose [1-2]: " tunnel_choice

    case $tunnel_choice in
        1) TUNNEL_TYPE="quick" ;;
        2) TUNNEL_TYPE="named" ;;
        *) TUNNEL_TYPE="quick" ;;
    esac

    # Port configuration
    read -p "Local port (default: 8080): " port_input
    LOCAL_PORT="${port_input:-8080}"

    # Named tunnel configuration
    if [ "$TUNNEL_TYPE" = "named" ]; then
        read -p "Cloudflare tunnel token: " TUNNEL_TOKEN

        # Auto-generate domain based on environment and current directory
        local default_domain="${ENVIRONMENT}.yourdomain.tld"
        if [ "$is_worktree" = "true" ]; then
            default_domain="${current_dir}.yourdomain.tld"
        fi

        read -p "Tunnel domain (default: $default_domain): " domain_input
        TUNNEL_DOMAIN="${domain_input:-$default_domain}"

        read -p "Tunnel name (default: ${current_dir}-${ENVIRONMENT}): " name_input
        TUNNEL_NAME="${name_input:-${current_dir}-${ENVIRONMENT}}"
    fi

    # WordPress settings
    read -p "Auto-set WordPress URLs? [Y/n]: " auto_urls
    AUTO_SET_URLS="${auto_urls:-Y}"

    read -p "Enable WordPress debug mode? [Y/n]: " debug_mode
    WP_DEBUG="${debug_mode:-Y}"

    # Save configuration
    local config_file="$DEFAULT_CONFIG"
    if [ "$is_worktree" = "true" ]; then
        config_file="$WORKTREE_CONFIG"
    fi

    save_config "$config_file"

    print_success "Environment '$ENVIRONMENT' configured!"
    echo ""
    show_config
}

# Show current configuration
show_config() {
    load_config || return 1

    print_header "Current Configuration"
    echo "📁 Directory: $(basename $(pwd))"
    echo "🌍 Environment: $ENVIRONMENT"
    echo "🔧 Tunnel Type: $TUNNEL_TYPE"
    echo "🔌 Local Port: $LOCAL_PORT"

    if [ "$TUNNEL_TYPE" = "named" ]; then
        echo "🌐 Domain: $TUNNEL_DOMAIN"
        echo "📝 Name: $TUNNEL_NAME"
    fi

    echo "🔄 Auto URLs: $AUTO_SET_URLS"
    echo "🐛 Debug Mode: $WP_DEBUG"
}

# Start tunnel based on configuration
start_tunnel() {
    load_config || return 1

    print_header "Starting $TUNNEL_TYPE tunnel for $ENVIRONMENT"

    # Update WordPress environment
    update_wp_environment

    if [ "$TUNNEL_TYPE" = "quick" ]; then
        start_quick_tunnel
    else
        start_named_tunnel
    fi
}

# Start quick tunnel
start_quick_tunnel() {
    print_status "Starting Cloudflare Quick Tunnel..."

    local container_name="tunnel-$(basename $(pwd))"

    # Stop existing tunnel
    $DOCKER_BIN stop "$container_name" 2>/dev/null || true
    $DOCKER_BIN rm "$container_name" 2>/dev/null || true

    # Start new tunnel
    $DOCKER_BIN run -d \
        --name "$container_name" \
        cloudflare/cloudflared:latest \
        tunnel --no-autoupdate --url "http://host.docker.internal:$LOCAL_PORT"

    sleep 3

    # Get tunnel URL
    local tunnel_url=$($DOCKER_BIN logs "$container_name" 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1)

    if [ ! -z "$tunnel_url" ]; then
        print_success "Quick tunnel started!"
        echo "🌐 URL: $tunnel_url"

        # Auto-set WordPress URLs if enabled
        if [ "$AUTO_SET_URLS" = "Y" ] || [ "$AUTO_SET_URLS" = "y" ]; then
            set_wp_urls "$tunnel_url"
        fi

        # Save tunnel URL to config
        echo "CURRENT_TUNNEL_URL=\"$tunnel_url\"" >> "$WORKTREE_CONFIG"
    else
        print_error "Failed to get tunnel URL"
        $DOCKER_BIN logs "$container_name"
    fi
}

# Start named tunnel
start_named_tunnel() {
    if [ -z "$TUNNEL_TOKEN" ]; then
        print_error "No tunnel token configured. Run 'init-env' first."
        return 1
    fi

    print_status "Starting Named Tunnel: $TUNNEL_DOMAIN"

    local container_name="named-tunnel-$(basename $(pwd))"

    # Stop existing tunnel
    $DOCKER_BIN stop "$container_name" 2>/dev/null || true
    $DOCKER_BIN rm "$container_name" 2>/dev/null || true

    # Start named tunnel
    $DOCKER_BIN run -d \
        --name "$container_name" \
        --restart unless-stopped \
        cloudflare/cloudflared:latest \
        tunnel --no-autoupdate run --token "$TUNNEL_TOKEN"

    if [ $? -eq 0 ]; then
        print_success "Named tunnel started!"
        echo "🌐 Domain: https://$TUNNEL_DOMAIN"

        # Auto-set WordPress URLs if enabled
        if [ "$AUTO_SET_URLS" = "Y" ] || [ "$AUTO_SET_URLS" = "y" ]; then
            set_wp_urls "https://$TUNNEL_DOMAIN"
        fi
    else
        print_error "Failed to start named tunnel"
    fi
}

# Stop tunnel
stop_tunnel() {
    local container_name="tunnel-$(basename $(pwd))"
    local named_container="named-tunnel-$(basename $(pwd))"

    print_status "Stopping tunnels for $(basename $(pwd))..."

    $DOCKER_BIN stop "$container_name" 2>/dev/null || true
    $DOCKER_BIN rm "$container_name" 2>/dev/null || true
    $DOCKER_BIN stop "$named_container" 2>/dev/null || true
    $DOCKER_BIN rm "$named_container" 2>/dev/null || true

    # Reset WordPress URLs to local
    set_wp_urls "http://localhost:$LOCAL_PORT"

    print_success "Tunnels stopped and URLs reset to localhost"
}

# Set WordPress URLs
set_wp_urls() {
    local url="$1"

    print_status "Setting WordPress URLs to: $url"

    $WPCLI_CMD option update home "$url" > /dev/null 2>&1
    $WPCLI_CMD option update siteurl "$url/wp" > /dev/null 2>&1

    # Flush permalinks
    $WPCLI_CMD rewrite flush --hard > /dev/null 2>&1

    print_success "WordPress URLs updated"
}

# Update WordPress environment settings
update_wp_environment() {
    load_config || return 1

    print_status "Updating WordPress environment..."

    # Set debug mode
    if [ "$WP_DEBUG" = "Y" ] || [ "$WP_DEBUG" = "y" ]; then
        $WPCLI_CMD config set WP_DEBUG true --raw > /dev/null 2>&1
        $WPCLI_CMD config set WP_DEBUG_LOG true --raw > /dev/null 2>&1
    else
        $WPCLI_CMD config set WP_DEBUG false --raw > /dev/null 2>&1
        $WPCLI_CMD config set WP_DEBUG_LOG false --raw > /dev/null 2>&1
    fi

    # Set environment-specific constants
    $WPCLI_CMD config set WP_ENV "$ENVIRONMENT" > /dev/null 2>&1

    print_success "Environment settings updated"
}

# Show tunnel status
show_status() {
    print_header "Tunnel Status for $(basename $(pwd))"

    local container_name="tunnel-$(basename $(pwd))"
    local named_container="named-tunnel-$(basename $(pwd))"

    # Check quick tunnel
    if $DOCKER_BIN ps | grep -q "$container_name"; then
        print_success "Quick tunnel is running"
        local tunnel_url=$($DOCKER_BIN logs "$container_name" 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1)
        if [ ! -z "$tunnel_url" ]; then
            echo "🌐 URL: $tunnel_url"
        fi
    fi

    # Check named tunnel
    if $DOCKER_BIN ps | grep -q "$named_container"; then
        load_config
        print_success "Named tunnel is running"
        echo "🌐 Domain: https://$TUNNEL_DOMAIN"
    fi

    # Show current WordPress URLs
    echo ""
    print_status "Current WordPress URLs:"
    local home_url=$($WPCLI_CMD option get home 2>/dev/null)
    local site_url=$($WPCLI_CMD option get siteurl 2>/dev/null)

    if [ ! -z "$home_url" ]; then
        echo "🏠 Home: $home_url"
        echo "🔗 Site: $site_url"
    fi
}

# List all environments
list_envs() {
    print_header "Available Environments"

    if [ -d "$CONFIG_DIR" ]; then
        for config in "$CONFIG_DIR"/*.conf; do
            if [ -f "$config" ]; then
                local env_name=$(basename "$config" .conf)
                local env_type=$(grep "ENVIRONMENT=" "$config" | cut -d'"' -f2)
                local tunnel_type=$(grep "TUNNEL_TYPE=" "$config" | cut -d'"' -f2)

                echo "📁 $env_name ($env_type) - $tunnel_type tunnel"
            fi
        done
    else
        print_warning "No environments configured yet"
    fi
}

# Switch environment
switch_env() {
    local target_env="$1"

    if [ -z "$target_env" ]; then
        print_error "Usage: switch-env <environment-name>"
        return 1
    fi

    local target_config="$CONFIG_DIR/$target_env.conf"

    if [ ! -f "$target_config" ]; then
        print_error "Environment '$target_env' not found"
        return 1
    fi

    # Copy target config to current worktree config
    cp "$target_config" "$WORKTREE_CONFIG"

    print_success "Switched to environment: $target_env"
    show_config
}

# Show help
show_help() {
    print_header "Advanced Tunnel Manager"
    echo ""
    echo "Usage: ./tunnel-manager.sh [command] [options]"
    echo ""
    echo "Setup Commands:"
    echo "  init-env             - Initialize/configure environment"
    echo "  show-config          - Show current configuration"
    echo "  list-envs            - List all environments"
    echo "  switch-env <name>    - Switch to different environment"
    echo ""
    echo "Tunnel Commands:"
    echo "  start                - Start tunnel based on config"
    echo "  stop                 - Stop tunnel and reset URLs"
    echo "  status               - Show tunnel status"
    echo "  restart              - Stop and start tunnel"
    echo ""
    echo "Examples:"
    echo "  ./tunnel-manager.sh init-env      # Setup new environment"
    echo "  ./tunnel-manager.sh start         # Start configured tunnel"
    echo "  ./tunnel-manager.sh switch-env staging"
    echo ""
    echo "Git Worktree Support:"
    echo "  - Each worktree can have its own tunnel configuration"
    echo "  - Configurations are stored in .tunnel-configs/"
    echo "  - Automatic environment detection and port management"
}

# Initialize on first run
init_configs

# Main script logic
case ${1:-help} in
    init-env)
        init_env
        ;;
    show-config)
        show_config
        ;;
    list-envs)
        list_envs
        ;;
    switch-env)
        switch_env "$2"
        ;;
    start)
        start_tunnel
        ;;
    stop)
        stop_tunnel
        ;;
    status)
        show_status
        ;;
    restart)
        stop_tunnel
        sleep 2
        start_tunnel
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
