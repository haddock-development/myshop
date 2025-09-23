# Security Guide

Complete security setup for your WordPress development environment with Cloudflare Tunnels and ngrok.

## 🔒 Security Features

### 1. Cloudflare Access Protection
Protect your public tunnels with authentication and access policies.

**Setup:**
```bash
# Show complete setup guide
./cloudflare-access.sh setup-guide

# Quick setup for different scenarios
./cloudflare-access.sh quick-setup team    # Team access
./cloudflare-access.sh quick-setup demo    # Client demos
./cloudflare-access.sh quick-setup secure  # High security

# Create policy examples documentation
./cloudflare-access.sh policy-examples

# Test access protection
./cloudflare-access.sh test-access yourdomain.com
```

**Makefile shortcuts:**
```bash
make access-setup        # Setup guide
make access-test         # Test protection
make access-policies     # Policy examples
make access-wp-security  # WordPress hardening
```

### 2. WordPress Security Hardening
Automatic security enhancements for development environments.

**Features:**
- Search engine indexing disabled
- Restrictive robots.txt
- Strong password reminders
- File modification restrictions (production)

**Apply security:**
```bash
./cloudflare-access.sh wp-security
# or
make access-wp-security
```

### 3. Environment Isolation
Separate configurations for different environments.

**Environment Files:**
- `.env` - Local development
- `.env.staging` - Staging environment
- `.env.production` - Production environment

**Security settings per environment:**
- **Development**: Debug enabled, file modifications allowed
- **Staging**: Limited debug, testing features enabled
- **Production**: Debug disabled, file modifications restricted

## 🌐 Tunnel Security

### Cloudflare Tunnels
- Zero Trust security model
- No open ports on your server
- Built-in DDoS protection
- Access policies and authentication

### ngrok Tunnels
- HTTP/HTTPS tunnels with inspection
- Custom subdomains (paid plans)
- Basic authentication available
- Request replay and inspection tools

## 🛡️ Access Control Policies

### Common Policy Types

#### 1. Team Access Only
```yaml
Policy Name: Development Team
Rule: Email ending in @yourcompany.com
Action: Allow
```

#### 2. Specific Users
```yaml
Policy Name: Authorized Users
Rule: Email is in [admin@company.com, dev@company.com]
Action: Allow
```

#### 3. Geographic Restrictions
```yaml
Policy Name: Country Restriction
Rule: Country is in [Germany, United States]
Action: Allow
```

#### 4. Time-based Access
```yaml
Policy Name: Business Hours
Rule: Time of day is 09:00-18:00
Action: Allow
```

#### 5. IP Whitelist
```yaml
Policy Name: Office Network
Rule: IP ranges is 192.168.1.0/24
Action: Allow
```

### Multi-layer Policies

#### Secure Development Environment
```yaml
Policy 1: Company email required
Policy 2: Geographic restriction (your country)
Policy 3: Time restriction (business hours)
Session Duration: 8 hours
```

#### Client Demo Setup
```yaml
Policy 1: Specific emails (temporary client access)
Policy 2: Time window (demo duration)
Policy 3: Single session
Auto-remove: After demo completion
```

#### Production Access
```yaml
Policy 1: Senior team members only
Policy 2: Device enrollment required
Policy 3: Short session duration (2 hours)
Policy 4: MFA required
Policy 5: Geographic + IP restrictions
```

## 🔐 Authentication Methods

### One-time PIN (Free)
- Email-based verification
- No additional setup required
- Perfect for development environments

### Social Identity Providers
- Google Workspace
- GitHub
- Microsoft Azure AD
- Custom SAML/OIDC

### Device Enrollment
- Certificate-based authentication
- Device management
- Enhanced security for production

## 📊 Monitoring & Logging

### Cloudflare Access Analytics
```bash
# View access logs
Dashboard → Zero Trust → Analytics → Access

# Available metrics:
- Login attempts and successes
- User access patterns
- Blocked access attempts
- Geographic distribution
```

### ngrok Request Inspection
```bash
# Open ngrok dashboard
./ngrok-tunnel.sh dashboard
# or browse to: http://127.0.0.1:4040

# Features:
- Real-time request inspection
- Traffic replay
- Response modification
- Performance metrics
```

## 🚨 Security Alerts

### Cloudflare Notifications
Set up alerts for:
- Failed login attempts
- New user access
- Unusual access patterns
- Geographic anomalies

### WordPress Security
Monitor for:
- Admin login attempts
- Plugin/theme changes
- Database modifications
- File system changes

## ⚡ Quick Security Workflows

### Development Environment
```bash
# 1. Start secure development
make named-tunnel-start
make access-setup

# 2. Configure team access
# Follow Cloudflare Access setup guide

# 3. Apply WordPress security
make access-wp-security

# 4. Test access
make access-test
```

### Client Demo
```bash
# 1. Start demo environment
make ngrok-start

# 2. Set temporary access (manual in Cloudflare)
# Add client emails to access policy

# 3. Demo completion
make ngrok-stop
# Remove client access from Cloudflare
```

### Production Deployment
```bash
# 1. Deploy to staging first
make deploy-staging

# 2. Test access policies
make access-test

# 3. Deploy to production
make deploy-production

# 4. Monitor access logs
# Check Cloudflare Zero Trust dashboard
```

## 📋 Security Checklist

### Pre-deployment
- [ ] Access policies configured
- [ ] WordPress security applied
- [ ] Test environment protection
- [ ] Authentication method selected
- [ ] Monitoring alerts configured

### Development
- [ ] Use team access policies
- [ ] Enable debug mode locally only
- [ ] Regular password updates
- [ ] Monitor access logs
- [ ] Update dependencies regularly

### Production
- [ ] Strict access policies
- [ ] Disable debug mode
- [ ] File modifications disabled
- [ ] Short session durations
- [ ] Geographic restrictions
- [ ] MFA required
- [ ] Regular security audits

### Post-deployment
- [ ] Monitor access patterns
- [ ] Review security logs
- [ ] Update access policies
- [ ] Remove unused access
- [ ] Document security incidents

## 🛠️ Troubleshooting

### Common Issues

#### Access Denied
```bash
# Check policy configuration
# Verify email/identity provider
# Check geographic restrictions
# Verify time-based restrictions
```

#### Tunnel Not Protected
```bash
# Verify Cloudflare Access application setup
./cloudflare-access.sh test-access yourdomain.com

# Check tunnel domain configuration
# Ensure DNS is properly configured
```

#### WordPress Login Issues
```bash
# Reset WordPress URLs
make url-local
make url-set URL=https://yourdomain.com

# Clear caches
docker compose exec php wp cache flush
```

## 📚 Additional Resources

- [Cloudflare Zero Trust Documentation](https://developers.cloudflare.com/cloudflare-one/)
- [ngrok Security Documentation](https://ngrok.com/docs/security/)
- [WordPress Security Best Practices](https://wordpress.org/support/article/hardening-wordpress/)
- [OWASP Web Application Security](https://owasp.org/www-project-top-ten/)

## 🔄 Regular Maintenance

### Weekly
- Review access logs
- Check for failed login attempts
- Update WordPress and plugins
- Verify tunnel status

### Monthly
- Audit access policies
- Remove unused access
- Update dependencies
- Security scan

### Quarterly
- Full security review
- Policy effectiveness analysis
- Update authentication methods
- Team access audit

---

💡 **Pro Tips:**
- Start with simple policies and enhance gradually
- Always test policies before client demonstrations
- Keep access policies documented and up to date
- Regular security training for team members
- Monitor access patterns for anomalies