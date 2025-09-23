#!/bin/bash

# Deployment & Environment Management Script
# Unified interface for all deployment operations
# Usage: ./deploy.sh [command] [options]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
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

print_header() {
    echo -e "${CYAN}🚀 $1${NC}"
}

print_env() {
    echo -e "${PURPLE}🌍 $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    local missing=()

    # Check for required commands
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v git >/dev/null 2>&1 || missing+=("git")

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing[*]}"
        return 1
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        return 1
    fi

    return 0
}

# Get current environment
get_current_env() {
    if [ -f ".tunnel-configs/$(basename $(pwd)).conf" ]; then
        source ".tunnel-configs/$(basename $(pwd)).conf"
        echo "$ENVIRONMENT"
    elif [ -f ".tunnel-configs/default.conf" ]; then
        source ".tunnel-configs/default.conf"
        echo "$ENVIRONMENT"
    else
        echo "development"
    fi
}

# Deploy to local development
deploy_local() {
    print_header "Deploying to Local Development"

    # Start Docker services
    print_status "Starting Docker services..."
    docker compose up -d

    # Wait for services
    print_status "Waiting for services to be ready..."
    sleep 10

    # Install/update dependencies
    print_status "Installing Composer dependencies..."
    docker compose exec php composer install

    # Update WordPress if needed
    print_status "Checking WordPress installation..."
    if docker compose exec php wp core is-installed --path="/var/www/html/web/wp" 2>/dev/null; then
        print_status "Updating WordPress core..."
        docker compose exec php wp core update-db --path="/var/www/html/web/wp"
        docker compose exec php wp rewrite flush --hard --path="/var/www/html/web/wp"
    else
        print_warning "WordPress not installed. Run initial setup first."
    fi

    print_success "Local deployment completed!"
    echo ""
    echo "🌐 Local URLs:"
    echo "   Shop:  http://localhost:8080"
    echo "   Admin: http://localhost:8080/wp/wp-admin"
    echo "   Mail:  http://localhost:8025"
}

# Deploy with tunnel
deploy_tunnel() {
    local tunnel_type="${1:-auto}"

    print_header "Deploying with Cloudflare Tunnel"

    # Ensure local services are running
    if ! docker compose ps | grep -q "Up"; then
        print_status "Starting local services first..."
        deploy_local
    fi

    # Start tunnel based on configuration
    if [ -x "./tunnel-manager.sh" ]; then
        print_status "Starting tunnel using tunnel-manager..."
        ./tunnel-manager.sh start
    else
        print_warning "tunnel-manager.sh not found, using basic tunnel..."
        ./tunnel.sh start
    fi

    print_success "Tunnel deployment completed!"
}

# Deploy to staging
deploy_staging() {
    print_header "Deploying to Staging via GitHub Actions"

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi

    # Check for uncommitted changes
    if ! git diff --quiet; then
        print_warning "You have uncommitted changes"
        read -p "Commit changes first? [Y/n]: " commit_first
        if [[ "$commit_first" =~ ^[Yy]?$ ]]; then
            git add .
            read -p "Commit message: " commit_msg
            git commit -m "${commit_msg:-Deploy to staging}"
        fi
    fi

    # Push to staging branch
    local current_branch=$(git branch --show-current)
    print_status "Pushing $current_branch to trigger staging deployment..."

    if [ "$current_branch" = "develop" ] || [ "$current_branch" = "staging" ]; then
        git push origin "$current_branch"
    else
        print_status "Creating staging branch from $current_branch..."
        git checkout -b staging
        git push -u origin staging
        git checkout "$current_branch"
    fi

    print_success "Staging deployment triggered!"
    echo ""
    echo "🔗 Check deployment status:"
    echo "   GitHub Actions: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
}

# Deploy to production
deploy_production() {
    print_header "Deploying to Production"

    print_warning "This will deploy to PRODUCTION environment!"
    read -p "Are you sure? Type 'PRODUCTION' to confirm: " confirm

    if [ "$confirm" != "PRODUCTION" ]; then
        print_error "Production deployment cancelled"
        return 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi

    # Ensure we're on main/master branch
    local current_branch=$(git branch --show-current)
    if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
        print_error "Production deployments must be from main/master branch"
        print_status "Current branch: $current_branch"
        return 1
    fi

    # Check for uncommitted changes
    if ! git diff --quiet; then
        print_error "You have uncommitted changes. Commit or stash them first."
        return 1
    fi

    # Trigger production deployment
    print_status "Triggering production deployment via GitHub Actions..."

    # Use GitHub CLI if available, otherwise provide manual instructions
    if command -v gh >/dev/null 2>&1; then
        gh workflow run deploy-staging.yml -f environment=production
        print_success "Production deployment triggered!"
    else
        print_status "GitHub CLI not found. Trigger manually:"
        echo "1. Go to: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
        echo "2. Run 'Deploy to Staging' workflow"
        echo "3. Select 'production' environment"
    fi
}

# Show deployment status
show_status() {
    print_header "Deployment Status"

    local current_env=$(get_current_env)
    print_env "Current Environment: $current_env"

    # Check local Docker services
    echo ""
    print_status "Local Services:"
    if docker compose ps 2>/dev/null | grep -q "Up"; then
        print_success "Docker services are running"

        # Show service URLs
        echo "🌐 Local URLs:"
        echo "   Shop:  http://localhost:8080"
        echo "   Admin: http://localhost:8080/wp/wp-admin"
        echo "   Mail:  http://localhost:8025"

        # Check WordPress status
        if curl -s -f http://localhost:8080 >/dev/null 2>&1; then
            print_success "WordPress is accessible"
        else
            print_warning "WordPress is not responding"
        fi
    else
        print_warning "Docker services are not running"
    fi

    # Check tunnel status
    echo ""
    print_status "Tunnel Status:"
    if [ -x "./tunnel-manager.sh" ]; then
        ./tunnel-manager.sh status
    else
        print_warning "Tunnel manager not available"
    fi

    # Show git status
    echo ""
    print_status "Git Status:"
    if git rev-parse --git-dir >/dev/null 2>&1; then
        local current_branch=$(git branch --show-current)
        local commit_hash=$(git rev-parse --short HEAD)
        echo "📁 Branch: $current_branch"
        echo "📝 Commit: $commit_hash"

        if ! git diff --quiet; then
            print_warning "You have uncommitted changes"
        else
            print_success "Working directory is clean"
        fi
    else
        print_warning "Not in a git repository"
    fi
}

# Initialize new environment
init_environment() {
    local env_name="$1"

    if [ -z "$env_name" ]; then
        print_error "Usage: init <environment-name>"
        return 1
    fi

    print_header "Initializing Environment: $env_name"

    # Create environment-specific configuration
    if [ -x "./tunnel-manager.sh" ]; then
        print_status "Setting up tunnel configuration..."
        ./tunnel-manager.sh init-env
    fi

    # Create environment-specific docker override if needed
    if [ ! -f "docker-compose.override.yml" ]; then
        print_status "Creating Docker override template..."
        cat > "docker-compose.override.yml" << 'EOF'
# Environment-specific Docker overrides
# This file is environment-specific and should not be committed

version: '3.8'

services:
  # Uncomment and modify as needed
  # php:
  #   environment:
  #     - CUSTOM_ENV_VAR=value

  # nginx:
  #   ports:
  #     - "8081:80"  # Use different port if needed
EOF
        echo "docker-compose.override.yml" >> .gitignore
    fi

    print_success "Environment '$env_name' initialized!"
    echo ""
    echo "Next steps:"
    echo "1. ./deploy.sh local     # Deploy locally"
    echo "2. ./deploy.sh tunnel    # Deploy with tunnel"
    echo "3. ./deploy.sh status    # Check status"
}

# Rollback deployment
rollback() {
    print_header "Rollback Deployment"

    print_warning "This will rollback to the previous state"
    read -p "Continue? [y/N]: " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_error "Rollback cancelled"
        return 1
    fi

    # For local rollback, we can reset git and redeploy
    if git rev-parse --git-dir >/dev/null 2>&1; then
        print_status "Rolling back to previous commit..."
        git reset --hard HEAD~1
        deploy_local
        print_success "Local rollback completed"
    else
        print_error "Git repository required for rollback"
    fi
}

# Show help
show_help() {
    print_header "Deployment & Environment Management"
    echo ""
    echo "Usage: ./deploy.sh [command] [options]"
    echo ""
    echo "Deployment Commands:"
    echo "  local                - Deploy to local development environment"
    echo "  tunnel [type]        - Deploy with Cloudflare tunnel"
    echo "  staging              - Deploy to staging via GitHub Actions"
    echo "  production           - Deploy to production via GitHub Actions"
    echo ""
    echo "Management Commands:"
    echo "  status               - Show current deployment status"
    echo "  init <env>           - Initialize new environment"
    echo "  rollback             - Rollback to previous deployment"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh local              # Local development"
    echo "  ./deploy.sh tunnel             # Quick tunnel"
    echo "  ./deploy.sh tunnel named       # Named tunnel"
    echo "  ./deploy.sh staging            # Deploy to staging"
    echo "  ./deploy.sh init feature-x     # Setup feature environment"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker & Docker Compose"
    echo "  - Git (for staging/production)"
    echo "  - GitHub CLI (optional, for production)"
}

# Main script logic
if ! check_prerequisites; then
    exit 1
fi

case ${1:-help} in
    local)
        deploy_local
        ;;
    tunnel)
        deploy_tunnel "$2"
        ;;
    staging)
        deploy_staging
        ;;
    production)
        deploy_production
        ;;
    status)
        show_status
        ;;
    init)
        init_environment "$2"
        ;;
    rollback)
        rollback
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