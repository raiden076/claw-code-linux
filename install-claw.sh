#!/bin/bash
# Claw Code Linux Installer
# One-liner install: curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/claw-code/main/install-claw.sh | bash

set -e

REPO="ultraworkers/claw-code"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        TARGET="x86_64-unknown-linux-gnu"
        ;;
    aarch64|arm64)
        TARGET="aarch64-unknown-linux-gnu"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH"
echo "Target: $TARGET"

# Get latest release
LATEST_URL="https://api.github.com/repos/$REPO/releases/latest"
echo "Fetching latest release from $REPO..."

if command -v curl &> /dev/null; then
    DOWNLOAD_URL=$(curl -s "$LATEST_URL" | grep -o "browser_download_url.*claw-$TARGET.tar.gz" | cut -d'"' -f4)
elif command -v wget &> /dev/null; then
    DOWNLOAD_URL=$(wget -qO- "$LATEST_URL" | grep -o "browser_download_url.*claw-$TARGET.tar.gz" | cut -d'"' -f4)
else
    echo "Error: curl or wget required"
    exit 1
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find release asset for $TARGET"
    exit 1
fi

echo "Downloading from: $DOWNLOAD_URL"

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download and extract
if command -v curl &> /dev/null; then
    curl -sSL "$DOWNLOAD_URL" -o "$TMP_DIR/claw.tar.gz"
else
    wget -q "$DOWNLOAD_URL" -O "$TMP_DIR/claw.tar.gz"
fi

tar -xzf "$TMP_DIR/claw.tar.gz" -C "$TMP_DIR"

# Install
mkdir -p "$INSTALL_DIR"
cp "$TMP_DIR/claw-$TARGET" "$INSTALL_DIR/claw"
chmod +x "$INSTALL_DIR/claw"

echo ""
echo "✅ claw installed to $INSTALL_DIR/claw"
echo ""

# Check if in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "⚠️  $INSTALL_DIR is not in your PATH"
    echo "   Add this to your shell config (~/.bashrc or ~/.zshrc):"
    echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo "Run 'claw --help' to get started"
