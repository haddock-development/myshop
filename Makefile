.PHONY: tunnel tunnel-alt url-set url-local named-tunnel-setup named-tunnel-start named-tunnel-stop named-tunnel-status named-tunnel-domain named-tunnel-local deploy-local deploy-tunnel deploy-staging deploy-production worktree-create worktree-list worktree-start worktree-stop status help

# === Quick Tunnels (temporary URLs) ===

# Start Cloudflare tunnel (Quick Tunnel)
tunnel:
	@echo "Starting Cloudflare Quick Tunnel..."
	@echo "Copy the tunnel URL from the output below and use 'make url-set URL=<tunnel-url>'"
	@docker run --rm -it cloudflare/cloudflared:latest \
		tunnel --no-autoupdate --url http://host.docker.internal:8080

# Alternative tunnel command for systems where --network host doesn't work
tunnel-alt:
	@echo "Starting Cloudflare Quick Tunnel (alternative method)..."
	@echo "Copy the tunnel URL from the output below and use 'make url-set URL=<tunnel-url>'"
	@docker run --rm -it cloudflare/cloudflared:latest \
		tunnel --no-autoupdate --url http://host.docker.internal:8080

# === Named Tunnels (stable subdomains) ===

# Setup named tunnel (interactive)
named-tunnel-setup:
	@./named-tunnel.sh setup

# Start named tunnel
named-tunnel-start:
	@./named-tunnel.sh start

# Stop named tunnel
named-tunnel-stop:
	@./named-tunnel.sh stop

# Show named tunnel status
named-tunnel-status:
	@./named-tunnel.sh status

# Set WordPress to use tunnel domain
named-tunnel-domain:
	@./named-tunnel.sh set-domain

# Reset WordPress to local URLs
named-tunnel-local:
	@./named-tunnel.sh reset-local

# === URL Management ===

# Set WordPress URLs to tunnel (usage: make url-set URL=https://abc12345.trycloudflare.com)
url-set:
	@if [ -z "$(URL)" ]; then \
		echo "Error: URL parameter required. Usage: make url-set URL=https://abc12345.trycloudflare.com"; \
		exit 1; \
	fi
	@echo "Setting WordPress URLs to: $(URL)"
	@docker compose run --rm wpcli option update home "$(URL)"
	@docker compose run --rm wpcli option update siteurl "$(URL)/wp"
	@echo "✅ WordPress URLs updated successfully!"
	@echo "Shop: $(URL)"
	@echo "Admin: $(URL)/wp/wp-admin"

# Reset WordPress URLs to local development
url-local:
	@echo "Resetting WordPress URLs to local development..."
	@$(MAKE) url-set URL=http://localhost:8080
	@echo "✅ URLs reset to local development"

# === Help ===

# Show help
help:
	@echo "🚀 Cloudflare Tunnel Commands for Bedrock WordPress"
	@echo ""
	@echo "=== Quick Tunnels (temporary URLs) ==="
	@echo "  make tunnel              - Start Quick Tunnel (copy URL manually)"
	@echo "  make tunnel-alt          - Alternative tunnel command for macOS"
	@echo ""
	@echo "=== Named Tunnels (stable subdomains) ==="
	@echo "  make named-tunnel-setup  - Setup named tunnel (interactive)"
	@echo "  make named-tunnel-start  - Start named tunnel container"
	@echo "  make named-tunnel-stop   - Stop named tunnel container"
	@echo "  make named-tunnel-status - Show tunnel status"
	@echo "  make named-tunnel-domain - Set WordPress to tunnel domain"
	@echo "  make named-tunnel-local  - Reset WordPress to localhost"
	@echo ""
	@echo "=== URL Management ==="
	@echo "  make url-set URL=<url>   - Set WordPress URLs manually"
	@echo "  make url-local           - Reset to localhost:8080"
	@echo ""
	@echo "=== Quick Workflows ==="
	@echo ""
	@echo "Quick Tunnel (temporary):"
	@echo "  1. make tunnel"
	@echo "  2. Copy URL from output"
	@echo "  3. make url-set URL=https://abc12345.trycloudflare.com"
	@echo "  4. make url-local (when finished)"
	@echo ""
	@echo "Named Tunnel (permanent subdomain):"
	@echo "  1. make named-tunnel-setup   # One-time setup"
	@echo "  2. make named-tunnel-start   # Start tunnel"
	@echo "  3. make named-tunnel-domain  # Use your domain"
	@echo "  4. make named-tunnel-local   # Back to localhost"
	@echo ""
	@echo "For more options, see: ./tunnel.sh help and ./named-tunnel.sh help"

# === Deployment Commands ===

# Deploy to local development
deploy-local:
	@./deploy.sh local

# Deploy with tunnel
deploy-tunnel:
	@./deploy.sh tunnel

# Deploy to staging
deploy-staging:
	@./deploy.sh staging

# Deploy to production
deploy-production:
	@./deploy.sh production

# Show deployment status
status:
	@./deploy.sh status

# === Git Worktrees Commands ===

# Create new worktree
worktree-create:
	@./worktree-manager.sh create $(BRANCH) $(NAME)

# List all worktrees
worktree-list:
	@./worktree-manager.sh list

# Start worktree services
worktree-start:
	@./worktree-manager.sh start $(NAME)

# Stop worktree services
worktree-stop:
	@./worktree-manager.sh stop $(NAME)

# === Extended Help ===

help-extended: help
	@echo ""
	@echo "🚀 **Extended Commands**"
	@echo ""
	@echo "=== Deployment ==="
	@echo "  make deploy-local        - Deploy to local development"
	@echo "  make deploy-tunnel       - Deploy with tunnel"
	@echo "  make deploy-staging      - Deploy to staging via GitHub Actions"
	@echo "  make deploy-production   - Deploy to production via GitHub Actions"
	@echo "  make status              - Show deployment status"
	@echo ""
	@echo "=== Git Worktrees ==="
	@echo "  make worktree-create BRANCH=feature/x NAME=myshop-feature-x"
	@echo "  make worktree-list       - List all worktrees"
	@echo "  make worktree-start NAME=myshop-feature-x"
	@echo "  make worktree-stop NAME=myshop-feature-x"
	@echo ""
	@echo "=== Advanced Usage ==="
	@echo ""
	@echo "Development Workflow:"
	@echo "  1. make worktree-create BRANCH=feature/new-feature"
	@echo "  2. cd ../myshop-feature-new-feature"
	@echo "  3. make deploy-local"
	@echo "  4. make deploy-tunnel"
	@echo ""
	@echo "Production Deployment:"
	@echo "  1. git checkout main"
	@echo "  2. make deploy-staging    # Test in staging first"
	@echo "  3. make deploy-production # Deploy to production"
	@echo ""
	@echo "Scripts available:"
	@echo "  ./deploy.sh              - Deployment management"
	@echo "  ./tunnel-manager.sh      - Advanced tunnel management"
	@echo "  ./worktree-manager.sh    - Git worktrees management"
	@echo "  ./wp-utils.sh            - WordPress utilities"