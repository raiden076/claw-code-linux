#!/bin/bash
# Claw Code Linux Installer with CLIProxyAPI Setup
# One-liner: curl -sSL https://raw.githubusercontent.com/USER/claw-code/main/install-claw.sh | bash

set -e

REPO="ultraworkers/claw-code"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
PROXY_DIR="${PROXY_DIR:-$HOME/.claw-proxy}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                🦀 Claw Code Installer                        ║"
    echo "║         AI Coding Agent + CLIProxyAPI Setup                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

detect_js_runtime() {
    echo -e "${BLUE}🔍 Detecting JavaScript runtime...${NC}"
    
    local runtimes=()
    
    if command -v bun &> /dev/null; then
        runtimes+=("Bun $(bun --version)")
    fi
    if command -v node &> /dev/null; then
        runtimes+=("Node.js $(node --version)")
    fi
    if command -v deno &> /dev/null; then
        runtimes+=("Deno $(deno --version | head -1)")
    fi
    
    if [ ${#runtimes[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️  No JavaScript runtime detected${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Found: ${runtimes[*]}${NC}"
        return 0
    fi
}

install_bun() {
    echo -e "${BLUE}📦 Installing Bun...${NC}"
    echo -e "${YELLOW}Bun is a fast JavaScript runtime we'll use for proxy management scripts${NC}"
    
    # Install Bun
    curl -fsSL https://bun.sh/install | bash
    
    # Source the updated PATH for this session
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    
    if command -v bun &> /dev/null; then
        echo -e "${GREEN}✅ Bun $(bun --version) installed successfully!${NC}"
        return 0
    else
        echo -e "${RED}❌ Bun installation failed${NC}"
        return 1
    fi
}

setup_cliproxyapi() {
    echo -e "${BLUE}🌐 Setting up CLIProxyAPI...${NC}"
    
    mkdir -p "$PROXY_DIR"
    cd "$PROXY_DIR"
    
    # Check if already cloned
    if [ -d "$PROXY_DIR/CLIProxyAPI" ]; then
        echo -e "${YELLOW}CLIProxyAPI already exists, updating...${NC}"
        cd CLIProxyAPI && git pull
    else
        echo -e "${BLUE}Cloning CLIProxyAPI...${NC}"
        git clone https://github.com/router-for-me/CLIProxyAPI.git
        cd CLIProxyAPI
    fi
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        echo -e "${YELLOW}⚠️  Go not found. CLIProxyAPI requires Go to build.${NC}"
        echo -e "${BLUE}Installing Go...${NC}"
        
        # Install Go based on architecture
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64)
                GO_ARCH="amd64"
                ;;
            aarch64|arm64)
                GO_ARCH="arm64"
                ;;
            *)
                echo -e "${RED}Unsupported architecture for Go install: $ARCH${NC}"
                exit 1
                ;;
        esac
        
        GO_VERSION="1.23.4"
        curl -sSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        export PATH="/usr/local/go/bin:$PATH"
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc
    fi
    
    echo -e "${BLUE}Building CLIProxyAPI...${NC}"
    go build -o cliproxyapi main.go
    
    # Create config
    if [ ! -f "$PROXY_DIR/config.yaml" ]; then
        cat > "$PROXY_DIR/config.yaml" << 'EOF'
# CLIProxyAPI Configuration
# This proxy allows you to use your existing AI subscriptions

server:
  port: 8080
  host: "127.0.0.1"

# Providers - add your accounts here
providers:
  # Example: Gemini CLI
  # gemini:
  #   - name: "account1"
  #     auth_type: "oauth"
  
  # Example: Claude Code  
  # claude:
  #   - name: "account1"
  #     auth_type: "oauth"

# Logging
log_level: "info"
EOF
        echo -e "${GREEN}✅ Created config at $PROXY_DIR/config.yaml${NC}"
    fi
    
    # Create startup script
    cat > "$PROXY_DIR/start-proxy.sh" << EOF
#!/bin/bash
cd "$PROXY_DIR/CLIProxyAPI"
./cliproxyapi --config "$PROXY_DIR/config.yaml"
EOF
    chmod +x "$PROXY_DIR/start-proxy.sh"
    
    # Create systemd service file
    cat > "$PROXY_DIR/claw-proxy.service" << EOF
[Unit]
Description=CLIProxyAPI for Claw Code
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROXY_DIR/CLIProxyAPI
ExecStart=$PROXY_DIR/CLIProxyAPI/cliproxyapi --config $PROXY_DIR/config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    echo -e "${GREEN}✅ CLIProxyAPI setup complete!${NC}"
    echo -e "${YELLOW}📋 Next steps for proxy:${NC}"
    echo -e "   1. Edit config: ${BLUE}nano $PROXY_DIR/config.yaml${NC}"
    echo -e "   2. Start proxy: ${BLUE}$PROXY_DIR/start-proxy.sh${NC}"
    echo -e "   3. Or install systemd service:"
    echo -e "      ${BLUE}sudo cp $PROXY_DIR/claw-proxy.service /etc/systemd/system/${NC}"
    echo -e "      ${BLUE}sudo systemctl enable --now claw-proxy${NC}"
}

install_claw() {
    echo -e "${BLUE}🔧 Installing Claw Code...${NC}"
    
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            TARGET="x86_64-unknown-linux-musl"
            ;;
        aarch64|arm64)
            TARGET="aarch64-unknown-linux-musl"
            ;;
        *)
            echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${BLUE}Target: $TARGET${NC}"
    
    # Get latest release
    LATEST_URL="https://api.github.com/repos/$REPO/releases/latest"
    echo -e "${BLUE}Fetching latest release...${NC}"
    
    if command -v curl &> /dev/null; then
        DOWNLOAD_URL=$(curl -s "$LATEST_URL" | grep -o "browser_download_url.*claw-$TARGET.tar.gz" | cut -d'"' -f4)
    elif command -v wget &> /dev/null; then
        DOWNLOAD_URL=$(wget -qO- "$LATEST_URL" | grep -o "browser_download_url.*claw-$TARGET.tar.gz" | cut -d'"' -f4)
    else
        echo -e "${RED}❌ Error: curl or wget required${NC}"
        exit 1
    fi
    
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}❌ Could not find release asset for $TARGET${NC}"
        echo -e "${YELLOW}Building from source instead...${NC}"
        
        # Fallback: build from source
        if ! command -v cargo &> /dev/null; then
            echo -e "${BLUE}Installing Rust...${NC}"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi
        
        TMP_DIR=$(mktemp -d)
        git clone --depth 1 https://github.com/$REPO.git "$TMP_DIR/claw"
        cd "$TMP_DIR/claw/rust"
        cargo build --release --package rusty-claude-cli
        mkdir -p "$INSTALL_DIR"
        cp target/release/claw "$INSTALL_DIR/claw"
        rm -rf "$TMP_DIR"
    else
        echo -e "${BLUE}Downloading from: $DOWNLOAD_URL${NC}"
        
        TMP_DIR=$(mktemp -d)
        trap "rm -rf $TMP_DIR" EXIT
        
        if command -v curl &> /dev/null; then
            curl -sSL "$DOWNLOAD_URL" -o "$TMP_DIR/claw.tar.gz"
        else
            wget -q "$DOWNLOAD_URL" -O "$TMP_DIR/claw.tar.gz"
        fi
        
        tar -xzf "$TMP_DIR/claw.tar.gz" -C "$TMP_DIR"
        
        mkdir -p "$INSTALL_DIR"
        cp "$TMP_DIR/claw-$TARGET" "$INSTALL_DIR/claw"
    fi
    
    chmod +x "$INSTALL_DIR/claw"
    
    # Verify installation
    if "$INSTALL_DIR/claw" --version &> /dev/null; then
        echo -e "${GREEN}✅ Claw installed successfully!${NC}"
    else
        echo -e "${RED}❌ Installation verification failed${NC}"
        exit 1
    fi
}

setup_environment() {
    echo -e "${BLUE}⚙️  Setting up environment...${NC}"
    
    # Add to PATH if needed
    SHELL_RC=""
    if [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi
    
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        if [ -n "$SHELL_RC" ]; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
            echo -e "${GREEN}✅ Added $INSTALL_DIR to PATH in $SHELL_RC${NC}"
        fi
    fi
    
    # Create claw wrapper script with proxy support
    cat > "$INSTALL_DIR/claw-with-proxy" << EOF
#!/bin/bash
# Claw with CLIProxyAPI integration

# Check if proxy is running
if ! curl -s http://127.0.0.1:8080/health &> /dev/null; then
    echo "⚠️  CLIProxyAPI not running. Start it with: $PROXY_DIR/start-proxy.sh"
    echo "   Or install the systemd service for auto-start"
fi

# Set proxy URL for Anthropic API
export ANTHROPIC_BASE_URL="http://127.0.0.1:8080/v1"

exec $INSTALL_DIR/claw "\$@"
EOF
    chmod +x "$INSTALL_DIR/claw-with-proxy"
    
    echo -e "${GREEN}✅ Environment configured${NC}"
}

main() {
    print_banner
    
    echo -e "${BLUE}This will install:${NC}"
    echo -e "   1. 🦀 Claw Code (static binary)"
    echo -e "   2. 🥟 Bun (JavaScript runtime) - if no JS runtime found"
    echo -e "   3. 🌐 CLIProxyAPI (API proxy for existing subscriptions)"
    echo ""
    
    read -p "Continue? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [ -n "$REPLY" ]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
    
    # Step 1: Check JS Runtime
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if ! detect_js_runtime; then
        echo -e "${YELLOW}Bun is a fast JavaScript runtime useful for scripting${NC}"
        read -p "Install Bun? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
            install_bun
        else
            echo -e "${YELLOW}Skipping Bun installation${NC}"
        fi
    fi
    
    # Step 2: Install Claw
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    install_claw
    
    # Step 3: Setup CLIProxyAPI
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Setup CLIProxyAPI for using existing AI subscriptions? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        setup_cliproxyapi
    else
        echo -e "${YELLOW}Skipping CLIProxyAPI setup${NC}"
    fi
    
    # Step 4: Environment setup
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    setup_environment
    
    # Summary
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉 Installation Complete!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Quick Start:${NC}"
    echo -e "   ${YELLOW}claw --help${NC}           Show help"
    echo -e "   ${YELLOW}claw${NC}                  Start interactive REPL"
    echo -e "   ${YELLOW}claw prompt "hi"${NC}      One-shot mode"
    echo ""
    echo -e "${BLUE}With Proxy:${NC}"
    echo -e "   ${YELLOW}claw-with-proxy${NC}       Use with CLIProxyAPI"
    echo -e "   ${YELLOW}$PROXY_DIR/start-proxy.sh${NC}  Start proxy server"
    echo ""
    echo -e "${BLUE}Configure Proxy:${NC}"
    echo -e "   Edit: ${YELLOW}nano $PROXY_DIR/config.yaml${NC}"
    echo -e "   Docs: ${YELLOW}https://help.router-for.me/${NC}"
    echo ""
    
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo -e "${YELLOW}⚠️  Restart your terminal or run: source $SHELL_RC${NC}"
    fi
}

main "$@"
