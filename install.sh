#!/bin/bash
set -e

REPO="raiden076/claw-code-linux"
VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) TARGET="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) TARGET="aarch64-unknown-linux-gnu" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest version if not specified
if [ "$VERSION" = "latest" ]; then
    VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
fi

echo "Installing claw $VERSION for $TARGET..."

# Download URL
URL="https://github.com/$REPO/releases/download/$VERSION/claw-$TARGET.tar.gz"

# Create temp directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download
echo "Downloading from $URL..."
curl -fsL "$URL" -o "$TMP_DIR/claw.tar.gz"

# Extract
tar -xzf "$TMP_DIR/claw.tar.gz" -C "$TMP_DIR"

# Install
BINARY="$TMP_DIR/claw-$TARGET"
chmod +x "$BINARY"

if [ -w "$INSTALL_DIR" ]; then
    mv "$BINARY" "$INSTALL_DIR/claw"
else
    echo "Need sudo to install to $INSTALL_DIR"
    sudo mv "$BINARY" "$INSTALL_DIR/claw"
fi

echo "✓ claw installed to $INSTALL_DIR/claw"
echo ""
echo "Run 'claw --help' to get started"
