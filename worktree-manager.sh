#!/bin/bash

# Git Worktrees Manager für WordPress Development
# Automatisches Setup von Worktrees mit eigenen Docker-Ports und Tunnel-URLs
# Usage: ./worktree-manager.sh [command] [options]

BASE_DIR=$(pwd)
WORKTREES_DIR="../"
BASE_PORT=8080

ensure_remote() {
    if ! git remote >/dev/null 2>&1; then
        print_warning "Keine Git-Remotes konfiguriert. Füge einen hinzu (z. B. mit bin/setup-github.sh) bevor du Worktrees für kollaboratives Arbeiten nutzt."
    else
        local remotes=$(git remote)
        if [ -z "$remotes" ]; then
            print_warning "Keine Git-Remotes konfiguriert. Füge einen hinzu (z. B. mit bin/setup-github.sh)."
        fi
    fi
}

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
    echo -e "${CYAN}🌳 $1${NC}"
}

# Get next available port
get_next_port() {
    local port=$BASE_PORT
    while lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; do
        ((port++))
    done
    echo $port
}

# Create Docker override for custom ports
create_docker_override() {
    local worktree_path="$1"
    local web_port="$2"
    local mail_port="$3"

    cat > "$worktree_path/docker-compose.override.yml" << EOF
# Auto-generated Docker override for worktree
# This file is specific to this worktree and should not be committed
services:
  nginx:
    ports:
      - "$web_port:80"

  mailhog:
    ports:
      - "$mail_port:8025"

  # Optional: separate database for complete isolation
  # db:
  #   environment:
  #     MYSQL_DATABASE: wp_$(basename "$worktree_path")
EOF

    echo "$worktree_path/docker-compose.override.yml" >> "$worktree_path/.gitignore"
}

# Create worktree with full setup
create_worktree() {
    local branch_name="$1"
    local worktree_name="$2"

    if [ -z "$branch_name" ]; then
        print_error "Usage: create <branch-name> [worktree-name]"
        return 1
    fi

    ensure_remote

    if [ -z "$worktree_name" ]; then
        worktree_name="myshop-$branch_name"
    fi

    local worktree_path="$WORKTREES_DIR$worktree_name"

    print_header "Creating Worktree: $worktree_name"

    # Check if branch exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        print_status "Using existing branch: $branch_name"
    else
        print_status "Creating new branch: $branch_name"
        git checkout -b "$branch_name"
        git checkout main  # Switch back to main
    fi

    # Create worktree
    print_status "Creating worktree at: $worktree_path"
    git worktree add "$worktree_path" "$branch_name"

    if [ $? -ne 0 ]; then
        print_error "Failed to create worktree"
        return 1
    fi

    # Get available ports
    local web_port=$(get_next_port)
    local mail_port=$((web_port + 1000))  # Offset for mail port

    # Create Docker override
    print_status "Setting up Docker configuration (Port: $web_port)"
    create_docker_override "$worktree_path" "$web_port" "$mail_port"

    # Copy tunnel scripts
    print_status "Setting up tunnel scripts"
    cp tunnel-manager.sh "$worktree_path/"
    cp tunnel.sh "$worktree_path/"
    cp named-tunnel.sh "$worktree_path/"
    cp wp-utils.sh "$worktree_path/"

    # Initialize tunnel configuration
    cd "$worktree_path"
    ./tunnel-manager.sh init-env

    print_success "Worktree '$worktree_name' created successfully!"
    echo ""
    echo "📁 Path: $worktree_path"
    echo "🌐 Web: http://localhost:$web_port"
    echo "📧 Mail: http://localhost:$mail_port"
    echo ""
    echo "Next steps:"
    echo "  cd $worktree_path"
    echo "  $DOCKER_COMPOSE_CMD up -d"
    echo "  ./tunnel-manager.sh start"

    cd "$BASE_DIR"
}

# List all worktrees
list_worktrees() {
    print_header "Git Worktrees Overview"

    if ! git worktree list >/dev/null 2>&1; then
        print_warning "Not in a git repository"
        return 1
    fi

    git worktree list | while read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $NF}' | tr -d '[]')

        if [ "$path" = "$(pwd)" ]; then
            echo "🏠 $(basename "$path") (main) - $branch"
        else
            local web_port="Not configured"
            local tunnel_status="❌"

            # Check for Docker override
            if [ -f "$path/docker-compose.override.yml" ]; then
                web_port=$(grep -A 1 'ports:' "$path/docker-compose.override.yml" | grep -o '[0-9]\+:80' | cut -d: -f1)
                web_port="http://localhost:$web_port"
            fi

            # Check if Docker is running
            if [ -f "$path/docker-compose.yml" ]; then
                cd "$path" 2>/dev/null
                if $DOCKER_COMPOSE_CMD ps 2>/dev/null | grep -q "Up"; then
                    tunnel_status="✅"
                fi
                cd "$BASE_DIR"
            fi

            echo "🌳 $(basename "$path") - $branch"
            echo "   Web: $web_port"
            echo "   Status: $tunnel_status"
        fi
    done
}

# Switch to worktree
switch_worktree() {
    local worktree_name="$1"

    if [ -z "$worktree_name" ]; then
        print_error "Usage: switch <worktree-name>"
        return 1
    fi

    local worktree_path="$WORKTREES_DIR$worktree_name"

    if [ ! -d "$worktree_path" ]; then
        print_error "Worktree '$worktree_name' not found"
        return 1
    fi

    print_success "Switching to worktree: $worktree_name"
    echo "Run: cd $worktree_path"
}

# Start all services for a worktree
start_worktree() {
    local worktree_name="$1"

    if [ -z "$worktree_name" ]; then
        # Start current worktree
        if [ -f "docker-compose.yml" ]; then
            print_status "Starting services..."
            $DOCKER_COMPOSE_CMD up -d
            ./tunnel-manager.sh start
        else
            print_error "No docker-compose.yml found. Are you in a worktree?"
        fi
        return
    fi

    local worktree_path="$WORKTREES_DIR$worktree_name"

    if [ ! -d "$worktree_path" ]; then
        print_error "Worktree '$worktree_name' not found"
        return 1
    fi

    print_status "Starting services for: $worktree_name"
    cd "$worktree_path"
    $DOCKER_COMPOSE_CMD up -d
    ./tunnel-manager.sh start
    cd "$BASE_DIR"
}

# Stop all services for a worktree
stop_worktree() {
    local worktree_name="$1"

    if [ -z "$worktree_name" ]; then
        # Stop current worktree
        if [ -f "docker-compose.yml" ]; then
            print_status "Stopping services..."
            ./tunnel-manager.sh stop
            $DOCKER_COMPOSE_CMD down
        fi
        return
    fi

    local worktree_path="$WORKTREES_DIR$worktree_name"

    if [ ! -d "$worktree_path" ]; then
        print_error "Worktree '$worktree_name' not found"
        return 1
    fi

    print_status "Stopping services for: $worktree_name"
    cd "$worktree_path"
    ./tunnel-manager.sh stop
    $DOCKER_COMPOSE_CMD down
    cd "$BASE_DIR"
}

# Remove worktree
remove_worktree() {
    local worktree_name="$1"

    if [ -z "$worktree_name" ]; then
        print_error "Usage: remove <worktree-name>"
        return 1
    fi

    local worktree_path="$WORKTREES_DIR$worktree_name"

    if [ ! -d "$worktree_path" ]; then
        print_error "Worktree '$worktree_name' not found"
        return 1
    fi

    print_warning "This will remove the worktree and stop all services."
    read -p "Continue? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        print_status "Stopping services..."
        stop_worktree "$worktree_name"

        print_status "Removing worktree..."
        git worktree remove "$worktree_path" --force

        print_success "Worktree '$worktree_name' removed"
    else
        print_status "Operation cancelled"
    fi
}

# Sync changes between worktrees
sync_worktree() {
    local target_branch="$1"

    if [ -z "$target_branch" ]; then
        target_branch="main"
    fi

    print_status "Syncing with $target_branch..."

    # Fetch latest changes
    git fetch origin

    # Merge or rebase changes
    if git merge-base --is-ancestor "$target_branch" HEAD; then
        print_status "Already up to date"
    else
        print_status "Merging changes from $target_branch"
        git merge "origin/$target_branch"
    fi
}

# Show worktree status with URLs
status_all() {
    print_header "All Worktrees Status"

    git worktree list | while read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $NF}' | tr -d '[]')

        echo ""
        echo "📁 $(basename "$path") ($branch)"

        if [ "$path" != "$(pwd)" ] && [ -f "$path/docker-compose.yml" ]; then
            cd "$path" 2>/dev/null

            # Check Docker status
            if $DOCKER_COMPOSE_CMD ps 2>/dev/null | grep -q "Up"; then
                echo "   🐳 Docker: Running"

                # Get web port
                if [ -f "docker-compose.override.yml" ]; then
                    local web_port=$(grep -A 1 'ports:' "docker-compose.override.yml" | grep -o '[0-9]\+:80' | cut -d: -f1)
                    echo "   🌐 Local: http://localhost:$web_port"
                fi

                # Check tunnel status
                if [ -x "./tunnel-manager.sh" ]; then
                    ./tunnel-manager.sh status | grep -E "(URL|Domain)" | sed 's/^/   /'
                fi
            else
                echo "   🐳 Docker: Stopped"
            fi

            cd "$BASE_DIR"
        fi
    done
}

# Show help
show_help() {
    print_header "Git Worktrees Manager"
    echo ""
    echo "Usage: ./worktree-manager.sh [command] [options]"
    echo ""
    echo "Worktree Management:"
    echo "  create <branch> [name]   - Create new worktree with Docker setup"
    echo "  list                     - List all worktrees with status"
    echo "  switch <name>            - Get command to switch to worktree"
    echo "  remove <name>            - Remove worktree (with confirmation)"
    echo ""
    echo "Service Management:"
    echo "  start [name]             - Start Docker + tunnel for worktree"
    echo "  stop [name]              - Stop Docker + tunnel for worktree"
    echo "  status                   - Show status of all worktrees"
    echo ""
    echo "Development:"
    echo "  sync [branch]            - Sync current worktree with main/branch"
    echo ""
    echo "Examples:"
    echo "  ./worktree-manager.sh create feature/payment"
    echo "  ./worktree-manager.sh create hotfix/bug-123 myshop-hotfix"
    echo "  ./worktree-manager.sh start myshop-feature-payment"
    echo "  ./worktree-manager.sh status"
    echo ""
    echo "Each worktree gets:"
    echo "  - Unique Docker ports (auto-assigned)"
    echo "  - Independent tunnel configuration"
    echo "  - Separate WordPress environment"
    echo "  - Git isolation for parallel development"
}

# Main script logic
case ${1:-help} in
    create)
        create_worktree "$2" "$3"
        ;;
    list)
        list_worktrees
        ;;
    switch)
        switch_worktree "$2"
        ;;
    remove)
        remove_worktree "$2"
        ;;
    start)
        start_worktree "$2"
        ;;
    stop)
        stop_worktree "$2"
        ;;
    status)
        status_all
        ;;
    sync)
        sync_worktree "$2"
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
