#!/bin/bash

# Production Setup Script for Cloudflare Tunnel Deployment
# This sets up a production-ready WordPress environment with Cloudflare Tunnels
# Usage: ./setup-production.sh

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

print_header() {
    echo -e "${CYAN}🚀 $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing=()

    # Check required commands
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v curl >/dev/null 2>&1 || missing+=("curl")

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required commands: ${missing[*]}"
        return 1
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running"
        return 1
    fi

    print_success "All prerequisites met"
}

# Generate WordPress salts
generate_salts() {
    print_status "Generating WordPress security salts..."

    curl -s https://api.wordpress.org/secret-key/1.1/salt/ | while IFS= read -r line; do
        if [[ $line == define* ]]; then
            # Extract key name and value
            key=$(echo "$line" | sed "s/define('\([^']*\)'.*/\1/")
            value=$(echo "$line" | sed "s/define('[^']*',\s*'\([^']*\)'.*/\1/")
            echo "$key='$value'"
        fi
    done > salts.tmp

    source salts.tmp
    rm salts.tmp

    print_success "WordPress salts generated"
}

# Setup GitHub repository
setup_github() {
    print_header "GitHub Repository Setup"

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_status "Initializing git repository..."
        git init
        git branch -M main
    fi

    # Check for remote
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_warning "No GitHub remote configured"
        echo ""
        echo "📋 Next steps:"
        echo "1. Create a new repository on GitHub"
        echo "2. Run: git remote add origin git@github.com:USERNAME/REPO.git"
        echo "3. Run: git push -u origin main"
        echo ""
        read -p "Press Enter when repository is created and remote is added..."
    fi

    print_success "Git repository configured"
}

# Generate environment files
setup_environments() {
    print_header "Setting up Environment Configurations"

    # Generate production .env template
    print_status "Creating production environment template..."

    cat > .env.production.example << 'EOF'
# Production Environment Configuration
# Copy this to .env for production deployment

WP_ENV=production
WP_HOME=https://yourdomain.com
WP_SITEURL=${WP_HOME}/wp

# Database Configuration
DB_NAME=wordpress_prod
DB_USER=wordpress
DB_PASSWORD=CHANGE_THIS_PASSWORD
DB_HOST=127.0.0.1

# Security Settings
DISALLOW_FILE_MODS=true
WP_DEBUG=false
WP_DEBUG_LOG=false
WP_DEBUG_DISPLAY=false

# WordPress Security Salts (generate new ones)
AUTH_KEY='put your unique phrase here'
SECURE_AUTH_KEY='put your unique phrase here'
LOGGED_IN_KEY='put your unique phrase here'
NONCE_KEY='put your unique phrase here'
AUTH_SALT='put your unique phrase here'
SECURE_AUTH_SALT='put your unique phrase here'
LOGGED_IN_SALT='put your unique phrase here'
NONCE_SALT='put your unique phrase here'

# Cloudflare Tunnel
# Set these in GitHub Secrets, not here
# TUNNEL_TOKEN=your_tunnel_token
EOF

    # Generate staging .env template
    cat > .env.staging.example << 'EOF'
# Staging Environment Configuration

WP_ENV=staging
WP_HOME=https://staging.yourdomain.com
WP_SITEURL=${WP_HOME}/wp

# Database Configuration
DB_NAME=wordpress_staging
DB_USER=wordpress
DB_PASSWORD=CHANGE_THIS_PASSWORD
DB_HOST=127.0.0.1

# Debug Settings (enabled for staging)
WP_DEBUG=true
WP_DEBUG_LOG=true
WP_DEBUG_DISPLAY=false

# WordPress Security Salts (use same as production or generate new)
AUTH_KEY='put your unique phrase here'
SECURE_AUTH_KEY='put your unique phrase here'
LOGGED_IN_KEY='put your unique phrase here'
NONCE_KEY='put your unique phrase here'
AUTH_SALT='put your unique phrase here'
SECURE_AUTH_SALT='put your unique phrase here'
LOGGED_IN_SALT='put your unique phrase here'
NONCE_SALT='put your unique phrase here'
EOF

    print_success "Environment templates created"
}

# Create secrets documentation
create_secrets_doc() {
    print_header "Creating GitHub Secrets Documentation"

    cat > GITHUB_SECRETS.md << 'EOF'
# GitHub Secrets Configuration

Set these secrets in your GitHub repository:
**Repository → Settings → Secrets and variables → Actions**

## Required Secrets

### Cloudflare Tunnel
- `PRODUCTION_TUNNEL_TOKEN` - Your Cloudflare tunnel token for production
- `STAGING_TUNNEL_TOKEN` - Your Cloudflare tunnel token for staging (optional)

### Domains
- `PRODUCTION_DOMAIN` - Your production domain (e.g., yourdomain.com)
- `STAGING_DOMAIN` - Your staging domain (e.g., staging.yourdomain.com)

### Database
- `DB_NAME` - Production database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password
- `DB_HOST` - Database host (default: 127.0.0.1)

### WordPress Security Salts
Generate these at: https://api.wordpress.org/secret-key/1.1/salt/

- `AUTH_KEY`
- `SECURE_AUTH_KEY`
- `LOGGED_IN_KEY`
- `NONCE_KEY`
- `AUTH_SALT`
- `SECURE_AUTH_SALT`
- `LOGGED_IN_SALT`
- `NONCE_SALT`

## Setup Steps

1. **Create Cloudflare Tunnel:**
   ```bash
   # In Cloudflare Dashboard:
   # Zero Trust → Networks → Tunnels → Create tunnel
   # Add public hostname: yourdomain.com → HTTP → localhost:8080
   # Copy the token
   ```

2. **Set GitHub Secrets:**
   - Go to your repository on GitHub
   - Settings → Secrets and variables → Actions
   - Add each secret from the list above

3. **Deploy:**
   ```bash
   git push origin main  # Triggers production deployment
   ```

## Testing

- **Staging**: Use workflow_dispatch to deploy to staging first
- **Production**: Push to main branch for automatic deployment

## Monitoring

- Check GitHub Actions for deployment status
- Monitor Cloudflare Tunnel dashboard
- Use `./deploy.sh status` locally
EOF

    print_success "Secrets documentation created"
}

# Setup production Docker configuration
setup_docker_production() {
    print_header "Setting up Production Docker Configuration"

    # Create production Docker override
    cat > docker-compose.prod.yml << 'EOF'
# Production Docker Compose Override
# Use with: docker compose -f docker-compose.yml -f docker-compose.prod.yml up

version: '3.8'

services:
  php:
    environment:
      - WP_ENV=production
    # Remove development volumes for security
    volumes:
      - .:/var/www/html:ro  # Read-only in production
      - uploads:/var/www/html/web/app/uploads

  nginx:
    # Production-ready Nginx configuration
    volumes:
      - .:/var/www/html:ro
      - ./.docker/nginx/conf.d:/etc/nginx/conf.d:ro
      - uploads:/var/www/html/web/app/uploads

  db:
    # Production database settings
    command: --default-authentication-plugin=mysql_native_password --max_connections=200
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-strong_root_password}

volumes:
  uploads:
    driver: local
EOF

    print_success "Production Docker configuration created"
}

# Create quick setup script
create_quick_setup() {
    print_header "Creating Quick Setup Scripts"

    # Local production test
    cat > quick-production-test.sh << 'EOF'
#!/bin/bash
# Quick Production Test Script

echo "🚀 Starting local production test..."

# Use production configuration
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

echo "⏳ Waiting for services..."
sleep 30

# Install WordPress in production mode
docker compose exec php composer install --no-dev --optimize-autoloader

echo "✅ Production test environment ready!"
echo "🌐 Test at: http://localhost:8080"
echo ""
echo "To stop: docker compose down"
EOF

    chmod +x quick-production-test.sh

    # Commit and deploy script
    cat > commit-and-deploy.sh << 'EOF'
#!/bin/bash
# Commit and Deploy Script

set -e

echo "📝 Committing changes..."
git add .
read -p "Commit message: " commit_msg
git commit -m "${commit_msg:-Production deployment update}"

echo "🚀 Pushing to trigger deployment..."
git push origin main

echo "✅ Deployment triggered!"
echo "🔍 Check status: https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
EOF

    chmod +x commit-and-deploy.sh

    print_success "Quick setup scripts created"
}

# Main setup function
main() {
    print_header "Production Setup for Cloudflare Tunnel Deployment"
    echo ""

    # Run setup steps
    check_prerequisites
    echo ""

    setup_github
    echo ""

    setup_environments
    echo ""

    create_secrets_doc
    echo ""

    setup_docker_production
    echo ""

    create_quick_setup
    echo ""

    # Final instructions
    print_header "Setup Complete! 🎉"
    echo ""
    echo "📋 Next Steps:"
    echo ""
    echo "1. **Set up Cloudflare Tunnel:**"
    echo "   - Go to Cloudflare Zero Trust → Networks → Tunnels"
    echo "   - Create tunnel, add hostname, copy token"
    echo ""
    echo "2. **Configure GitHub Secrets:**"
    echo "   - See GITHUB_SECRETS.md for complete list"
    echo "   - Add tunnel tokens, domain, database config"
    echo ""
    echo "3. **Test locally:**"
    echo "   ./quick-production-test.sh"
    echo ""
    echo "4. **Deploy to production:**"
    echo "   ./commit-and-deploy.sh"
    echo ""
    echo "📖 Documentation created:"
    echo "   - GITHUB_SECRETS.md"
    echo "   - .env.production.example"
    echo "   - .env.staging.example"
    echo "   - docker-compose.prod.yml"
    echo ""
    print_success "Ready for production deployment!"
}

# Run main function
main "$@"