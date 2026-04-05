#!/bin/bash
set -e

REPO="raiden076/claw-code-linux"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        TARGET="x86_64-unknown-linux-gnu"
        ;;
    aarch64|arm64)
        TARGET="aarch64-unknown-linux-gnu"
        ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        echo "Supported: x86_64, aarch64"
        exit 1
        ;;
esac

# Detect platform
PLATFORM=$(uname -s)
if [ "$PLATFORM" != "Linux" ]; then
    echo "❌ Unsupported platform: $PLATFORM"
    echo "Claw is currently only available for Linux"
    exit 1
fi

echo "🦀 Installing Claw for $TARGET..."

# Get latest release
LATEST_URL="https://github.com/${REPO}/releases/latest/download/claw-${TARGET}.tar.gz"

# Download
TMP_DIR=$(mktemp -d)
echo "📥 Downloading from ${LATEST_URL}..."
curl -fsSL "$LATEST_URL" -o "${TMP_DIR}/claw.tar.gz"

# Extract
echo "📦 Extracting..."
tar -xzf "${TMP_DIR}/claw.tar.gz" -C "$TMP_DIR"

# Install
mkdir -p "$INSTALL_DIR"
cp "${TMP_DIR}/claw-${TARGET}" "${INSTALL_DIR}/claw"
chmod +x "${INSTALL_DIR}/claw"

# Cleanup
rm -rf "$TMP_DIR"

# Check if in PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo "⚠️  $INSTALL_DIR is not in your PATH"
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
fi

echo ""
echo "✅ Claw installed successfully!"
echo ""
echo "📍 Location: ${INSTALL_DIR}/claw"
echo "🎯 Version: $("${INSTALL_DIR}/claw" --version 2>/dev/null || echo 'unknown')"
echo ""
echo "🚀 Get started:"
echo "    claw --help"
echo "    claw 'hello world'"
