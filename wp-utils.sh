#!/bin/bash

# WordPress Utility Scripts for Bedrock
# Useful helper commands for development and troubleshooting

DOCKER_COMPOSE_CMD="docker compose"
WPCLI_CMD="$DOCKER_COMPOSE_CMD run --rm wpcli"

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

# Show current WordPress URLs
show_urls() {
    print_status "Current WordPress URLs:"
    HOME_URL=$($WPCLI_CMD option get home 2>/dev/null)
    SITE_URL=$($WPCLI_CMD option get siteurl 2>/dev/null)

    if [ ! -z "$HOME_URL" ] && [ ! -z "$SITE_URL" ]; then
        echo "🏠 Home URL:  $HOME_URL"
        echo "🔗 Site URL:  $SITE_URL"
        echo "🔑 Admin:     $SITE_URL/wp-admin"
    else
        print_error "Could not retrieve WordPress URLs"
    fi
}

# Flush permalinks
flush_permalinks() {
    print_status "Flushing WordPress permalinks..."
    $WPCLI_CMD rewrite flush --hard > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Permalinks flushed successfully"
    else
        print_error "Failed to flush permalinks"
    fi
}

# Clear WordPress cache
clear_cache() {
    print_status "Clearing WordPress cache..."
    $WPCLI_CMD cache flush > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Cache cleared successfully"
    else
        print_error "Failed to clear cache"
    fi
}

# Show WordPress info
wp_info() {
    print_status "WordPress Information:"
    $WPCLI_CMD core version 2>/dev/null | head -1 | sed 's/^/📦 WordPress: /'
    $WPCLI_CMD option get admin_email 2>/dev/null | sed 's/^/📧 Admin Email: /'
    $WPCLI_CMD plugin list --status=active --format=count 2>/dev/null | sed 's/^/🔌 Active Plugins: /'
    $WPCLI_CMD theme list --status=active --format=count 2>/dev/null | sed 's/^/🎨 Active Themes: /'
}

# Show site health
site_health() {
    print_status "Checking site health..."

    # Check if WordPress is accessible
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200"; then
        print_success "WordPress is accessible on localhost:8080"
    else
        print_warning "WordPress may not be accessible on localhost:8080"
    fi

    # Check database connection
    if $WPCLI_CMD db check > /dev/null 2>&1; then
        print_success "Database connection is working"
    else
        print_error "Database connection failed"
    fi

    # Check WordPress installation
    if $WPCLI_CMD core is-installed > /dev/null 2>&1; then
        print_success "WordPress is properly installed"
    else
        print_error "WordPress installation is incomplete"
    fi
}

# Set WordPress to development mode
dev_mode() {
    print_status "Setting WordPress to development mode..."
    $WPCLI_CMD config set WP_DEBUG true --raw > /dev/null 2>&1
    $WPCLI_CMD config set WP_DEBUG_LOG true --raw > /dev/null 2>&1
    $WPCLI_CMD config set WP_DEBUG_DISPLAY false --raw > /dev/null 2>&1
    $WPCLI_CMD config set SCRIPT_DEBUG true --raw > /dev/null 2>&1
    print_success "Development mode enabled"
}

# Set WordPress to production mode
prod_mode() {
    print_status "Setting WordPress to production mode..."
    $WPCLI_CMD config set WP_DEBUG false --raw > /dev/null 2>&1
    $WPCLI_CMD config set WP_DEBUG_LOG false --raw > /dev/null 2>&1
    $WPCLI_CMD config set WP_DEBUG_DISPLAY false --raw > /dev/null 2>&1
    $WPCLI_CMD config set SCRIPT_DEBUG false --raw > /dev/null 2>&1
    print_success "Production mode enabled"
}

# Update WordPress admin user
update_admin() {
    if [ -z "$1" ]; then
        print_error "Usage: ./wp-utils.sh update-admin <new-password>"
        exit 1
    fi

    print_status "Updating admin password..."
    $WPCLI_CMD user update admin --user_pass="$1" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Admin password updated"
        echo "👤 Username: admin"
        echo "🔑 Password: $1"
    else
        print_error "Failed to update admin password"
    fi
}

# Fix file permissions
fix_permissions() {
    print_status "Fixing file permissions..."
    docker compose exec php chown -R www-data:www-data /var/www/html > /dev/null 2>&1
    docker compose exec php chmod -R 755 /var/www/html > /dev/null 2>&1
    docker compose exec php chmod -R 775 /var/www/html/web/app/uploads > /dev/null 2>&1
    print_success "File permissions fixed"
}

# Show help
show_help() {
    echo "WordPress Utility Scripts for Bedrock"
    echo ""
    echo "Usage: ./wp-utils.sh [command] [options]"
    echo ""
    echo "Information Commands:"
    echo "  show-urls        - Show current WordPress URLs"
    echo "  wp-info          - Show WordPress version and basic info"
    echo "  site-health      - Check site health and connectivity"
    echo ""
    echo "Maintenance Commands:"
    echo "  flush-permalinks - Flush WordPress permalink rules"
    echo "  clear-cache      - Clear WordPress cache"
    echo "  fix-permissions  - Fix file permissions"
    echo ""
    echo "Configuration Commands:"
    echo "  dev-mode         - Enable development mode (debug on)"
    echo "  prod-mode        - Enable production mode (debug off)"
    echo "  update-admin <pw> - Update admin user password"
    echo ""
    echo "Examples:"
    echo "  ./wp-utils.sh show-urls"
    echo "  ./wp-utils.sh flush-permalinks"
    echo "  ./wp-utils.sh update-admin newpassword123"
    echo "  ./wp-utils.sh site-health"
}

# Main script logic
case ${1:-help} in
    show-urls)
        show_urls
        ;;
    flush-permalinks)
        flush_permalinks
        ;;
    clear-cache)
        clear_cache
        ;;
    wp-info)
        wp_info
        ;;
    site-health)
        site_health
        ;;
    dev-mode)
        dev_mode
        ;;
    prod-mode)
        prod_mode
        ;;
    update-admin)
        update_admin "$2"
        ;;
    fix-permissions)
        fix_permissions
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