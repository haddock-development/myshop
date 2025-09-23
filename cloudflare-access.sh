#!/bin/bash

# Cloudflare Access Management Script
# Manages access protection for your tunneled WordPress site
# Usage: ./cloudflare-access.sh [command] [options]

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
    echo -e "${CYAN}🔒 $1${NC}"
}

# Show Cloudflare Access setup guide
show_setup_guide() {
    print_header "Cloudflare Access Setup Guide"
    echo ""
    echo "🎯 **Goal:** Protect your public tunnel with authentication"
    echo ""
    echo "📋 **Steps to set up Cloudflare Access:**"
    echo ""
    echo "1. **Go to Cloudflare Dashboard:**"
    echo "   https://dash.cloudflare.com → Your Domain → Zero Trust"
    echo ""
    echo "2. **Navigate to Access:**"
    echo "   Zero Trust → Access → Applications → Add an application"
    echo ""
    echo "3. **Application Configuration:**"
    echo "   - Application Type: Self-hosted"
    echo "   - Application Name: WordPress Dev Environment"
    echo "   - Domain: dev.yourdomain.tld (your tunnel domain)"
    echo "   - Path: Leave empty (protects entire domain)"
    echo ""
    echo "4. **Policy Configuration:**"
    echo "   - Policy Name: Dev Team Access"
    echo "   - Action: Allow"
    echo ""
    echo "5. **Identity Rules (choose one):**"
    echo ""
    echo "   **Option A - Email Domain:**"
    echo "   - Rule: Emails ending in"
    echo "   - Value: @yourcompany.com"
    echo ""
    echo "   **Option B - Specific Emails:**"
    echo "   - Rule: Email"
    echo "   - Value: admin@yourcompany.com, dev@yourcompany.com"
    echo ""
    echo "   **Option C - Anyone (for demos):**"
    echo "   - Rule: Everyone"
    echo "   - Note: Use with caution!"
    echo ""
    echo "6. **Identity Provider:**"
    echo "   - One-time PIN (free, email-based)"
    echo "   - Or: Google, GitHub, etc. (if configured)"
    echo ""
    echo "7. **Complete Setup:**"
    echo "   - Click Add application"
    echo "   - Test access by visiting your tunnel URL"
    echo ""
    print_success "Access protection is now active!"
}

# Test access protection
test_access() {
    local domain="$1"

    if [ -z "$domain" ]; then
        # Try to get domain from config
        if [ -f ".tunnel-configs/default.conf" ]; then
            source ".tunnel-configs/default.conf"
            domain="$TUNNEL_DOMAIN"
        fi
    fi

    if [ -z "$domain" ]; then
        print_error "No domain specified. Usage: test-access <domain>"
        return 1
    fi

    print_header "Testing Access Protection"
    print_status "Testing domain: https://$domain"

    # Test if Cloudflare Access is active
    local response=$(curl -s -I "https://$domain" | head -1)

    if echo "$response" | grep -q "302\|200"; then
        print_status "Domain is accessible"

        # Check for Cloudflare Access headers
        local cf_headers=$(curl -s -I "https://$domain" | grep -i "cf-")

        if [ ! -z "$cf_headers" ]; then
            print_success "Cloudflare protection detected"
            echo "Headers found:"
            echo "$cf_headers" | sed 's/^/   /'
        else
            print_warning "No Cloudflare protection headers detected"
        fi
    else
        print_error "Domain not accessible: $response"
    fi
}

# Show access logs (guide)
show_logs_guide() {
    print_header "Access Logs & Monitoring"
    echo ""
    echo "📊 **View Access Logs:**"
    echo "   Cloudflare Dashboard → Zero Trust → Analytics → Access"
    echo ""
    echo "📈 **Available Metrics:**"
    echo "   - Login attempts and successes"
    echo "   - User access patterns"
    echo "   - Blocked access attempts"
    echo "   - Geographic access distribution"
    echo ""
    echo "🔔 **Set up Alerts:**"
    echo "   Zero Trust → Settings → Notifications"
    echo "   - Failed login attempts"
    echo "   - New user access"
    echo "   - Unusual access patterns"
}

# Create access policies examples
create_policy_examples() {
    print_header "Access Policy Examples"

    cat > cloudflare-access-policies.md << 'EOF'
# Cloudflare Access Policy Examples

## 1. Development Team Only

**Use Case:** Only your development team should access the staging environment

**Configuration:**
- Rule Type: Email
- Operator: is in
- Value: dev@company.com, lead@company.com, admin@company.com

## 2. Company Domain Access

**Use Case:** Anyone with your company email can access

**Configuration:**
- Rule Type: Emails ending in
- Value: @yourcompany.com

## 3. Client Demo Access

**Use Case:** Temporary access for client presentations

**Configuration:**
- Rule Type: Email
- Operator: is in
- Value: client@clientcompany.com, yourname@yourcompany.com
- **Note:** Add temporary emails, remove after demo

## 4. Geographic Restrictions

**Use Case:** Only allow access from specific countries

**Configuration:**
- Rule Type: Country
- Operator: is in
- Value: Germany, United States, United Kingdom

## 5. Time-based Access

**Use Case:** Only allow access during business hours

**Configuration:**
- Rule Type: Time of day
- Operator: is in
- Value: 09:00 - 18:00 (your timezone)

## 6. IP Whitelist (Office Only)

**Use Case:** Only allow access from office network

**Configuration:**
- Rule Type: IP ranges
- Operator: is in
- Value: 192.168.1.0/24, your.office.ip.address/32

## 7. Multi-factor Authentication

**Use Case:** Require additional security for admin access

**Configuration:**
- Path: /wp/wp-admin/*
- Require: Email + Device enrollment
- Session Duration: 1 hour

## Common Policy Combinations

### Secure Development Environment
```
Policy 1: Company email (@company.com)
Policy 2: Geographic restriction (your country)
Policy 3: Time restriction (business hours)
```

### Client Demo Setup
```
Policy 1: Specific emails (add client emails temporarily)
Policy 2: Time restriction (demo time window)
Policy 3: Remove policy after demo
```

### Production-like Testing
```
Policy 1: Senior team members only
Policy 2: Require device enrollment
Policy 3: Short session duration (2 hours)
Policy 4: Geographic restriction
```

## Tips

- **Start simple:** Begin with email-based access
- **Test thoroughly:** Always test policies before demos
- **Document access:** Keep track of who has access
- **Regular cleanup:** Remove unused access rules
- **Monitor logs:** Check access patterns regularly
EOF

    print_success "Policy examples created: cloudflare-access-policies.md"
}

# Quick access setup for common scenarios
quick_setup() {
    local scenario="$1"

    print_header "Quick Access Setup: $scenario"

    case "$scenario" in
        "team")
            echo "📋 **Team Access Setup:**"
            echo ""
            echo "1. Application Type: Self-hosted"
            echo "2. Domain: dev.yourdomain.tld"
            echo "3. Policy: Email ending in @yourcompany.com"
            echo "4. Identity Provider: One-time PIN"
            echo ""
            print_success "Perfect for team development environments"
            ;;
        "demo")
            echo "📋 **Client Demo Setup:**"
            echo ""
            echo "1. Application Type: Self-hosted"
            echo "2. Domain: demo.yourdomain.tld"
            echo "3. Policy: Specific emails (add client emails)"
            echo "4. Session Duration: 4 hours"
            echo "5. Identity Provider: One-time PIN"
            echo ""
            print_warning "Remember to remove client access after demo!"
            ;;
        "secure")
            echo "📋 **High Security Setup:**"
            echo ""
            echo "1. Application Type: Self-hosted"
            echo "2. Domain: secure.yourdomain.tld"
            echo "3. Policy: Specific emails + Device enrollment"
            echo "4. Session Duration: 1 hour"
            echo "5. Geographic restriction: Your country only"
            echo "6. Time restriction: Business hours only"
            echo ""
            print_success "Maximum security for sensitive environments"
            ;;
        *)
            print_error "Unknown scenario: $scenario"
            echo "Available scenarios: team, demo, secure"
            ;;
    esac
}

# WordPress security enhancements
wp_security_setup() {
    print_header "WordPress Security Enhancements"

    print_status "Setting up WordPress security features..."

    # Check if WordPress is accessible
    if ! docker compose ps | grep -q "Up"; then
        print_error "WordPress containers are not running"
        return 1
    fi

    # Disable search engine indexing
    print_status "Disabling search engine indexing..."
    docker compose exec -T php wp option update blog_public 0 --path="/var/www/html/web/wp" 2>/dev/null || true

    # Create robots.txt
    print_status "Creating restrictive robots.txt..."
    cat > web/robots.txt << 'EOF'
# Robots.txt for development/staging environment
# This site should NOT be indexed by search engines

User-agent: *
Disallow: /

# Block common crawlers explicitly
User-agent: Googlebot
Disallow: /

User-agent: Bingbot
Disallow: /

User-agent: Slurp
Disallow: /
EOF

    # Set up strong admin password reminder
    print_warning "Security Checklist:"
    echo "   ☐ Change default admin password (admin/admin)"
    echo "   ☐ Use strong passwords for all users"
    echo "   ☐ Enable Cloudflare Access protection"
    echo "   ☐ Disable search engine indexing ✅"
    echo "   ☐ Create restrictive robots.txt ✅"
    echo "   ☐ Regular security updates"

    print_success "WordPress security enhancements applied"
}

# Show help
show_help() {
    print_header "Cloudflare Access Management"
    echo ""
    echo "Usage: ./cloudflare-access.sh [command] [options]"
    echo ""
    echo "Setup Commands:"
    echo "  setup-guide          - Show complete Cloudflare Access setup guide"
    echo "  quick-setup <type>   - Quick setup for common scenarios"
    echo "                        Types: team, demo, secure"
    echo "  policy-examples      - Create policy examples documentation"
    echo ""
    echo "Testing & Monitoring:"
    echo "  test-access [domain] - Test if access protection is working"
    echo "  logs-guide           - Show how to view access logs"
    echo ""
    echo "Security:"
    echo "  wp-security          - Apply WordPress security enhancements"
    echo ""
    echo "Examples:"
    echo "  ./cloudflare-access.sh setup-guide"
    echo "  ./cloudflare-access.sh quick-setup team"
    echo "  ./cloudflare-access.sh test-access dev.yourdomain.tld"
    echo "  ./cloudflare-access.sh wp-security"
    echo ""
    echo "🔒 **Purpose:** Protect your public tunnels with authentication"
    echo "📚 **Docs:** See cloudflare-access-policies.md after running policy-examples"
}

# Main script logic
case ${1:-help} in
    setup-guide)
        show_setup_guide
        ;;
    quick-setup)
        quick_setup "$2"
        ;;
    test-access)
        test_access "$2"
        ;;
    logs-guide)
        show_logs_guide
        ;;
    policy-examples)
        create_policy_examples
        ;;
    wp-security)
        wp_security_setup
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