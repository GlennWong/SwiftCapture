#!/bin/bash

# SwiftCapture Release Build Script
# This script builds optimized release binaries for distribution

set -e  # Exit on any error

# Configuration
PRODUCT_NAME="SwiftCapture"
BINARY_NAME="scap"
BUILD_DIR=".build"
RELEASE_DIR="release"
VERSION="2.1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Building SwiftCapture v${VERSION} for release...${NC}"

# Check system requirements
echo -e "${YELLOW}📋 Checking system requirements...${NC}"

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
REQUIRED_VERSION="12.3"

if [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$MACOS_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]]; then
    echo -e "${RED}❌ Error: macOS $REQUIRED_VERSION or later required. Current: $MACOS_VERSION${NC}"
    exit 1
fi

# Check Xcode version
if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Error: Swift/Xcode not found. Please install Xcode 14.3 or later.${NC}"
    exit 1
fi

SWIFT_VERSION=$(swift --version | head -n1)
echo -e "${GREEN}✅ Swift found: $SWIFT_VERSION${NC}"

# Check for required frameworks (ScreenCaptureKit availability)
echo -e "${YELLOW}🔍 Checking ScreenCaptureKit availability...${NC}"
if [[ "$MACOS_VERSION" < "12.3" ]]; then
    echo -e "${RED}❌ Error: ScreenCaptureKit requires macOS 12.3 or later${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ScreenCaptureKit available${NC}"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi
if [ -d "$RELEASE_DIR" ]; then
    rm -rf "$RELEASE_DIR"
fi

# Create release directory
mkdir -p "$RELEASE_DIR"

# Build release version
echo -e "${YELLOW}🔨 Building release version...${NC}"
swift build -c release --disable-sandbox

# Check if build was successful
if [ ! -f "$BUILD_DIR/release/$PRODUCT_NAME" ]; then
    echo -e "${RED}❌ Build failed: Binary not found at $BUILD_DIR/release/$PRODUCT_NAME${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Copy binary to release directory
echo -e "${YELLOW}📦 Preparing release package...${NC}"
cp "$BUILD_DIR/release/$PRODUCT_NAME" "$RELEASE_DIR/$BINARY_NAME"

# Make binary executable
chmod +x "$RELEASE_DIR/$BINARY_NAME"

# Get binary info
BINARY_SIZE=$(du -h "$RELEASE_DIR/$BINARY_NAME" | cut -f1)
BINARY_PATH=$(realpath "$RELEASE_DIR/$BINARY_NAME")

echo -e "${GREEN}✅ Release binary created:${NC}"
echo -e "   📍 Location: $BINARY_PATH"
echo -e "   📏 Size: $BINARY_SIZE"

# Test the binary
echo -e "${YELLOW}🧪 Testing release binary...${NC}"

# Test version command
if ! "$RELEASE_DIR/$BINARY_NAME" --version &> /dev/null; then
    echo -e "${RED}❌ Error: Binary version test failed${NC}"
    exit 1
fi

# Test help command
if ! "$RELEASE_DIR/$BINARY_NAME" --help &> /dev/null; then
    echo -e "${RED}❌ Error: Binary help test failed${NC}"
    exit 1
fi

# Test screen list (should work even without permissions)
if ! "$RELEASE_DIR/$BINARY_NAME" --screen-list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Warning: Screen list test failed (may require permissions)${NC}"
else
    echo -e "${GREEN}✅ Screen list test passed${NC}"
fi

echo -e "${GREEN}✅ Binary tests passed${NC}"

# Create installation script
echo -e "${YELLOW}📝 Creating installation script...${NC}"
cat > "$RELEASE_DIR/install.sh" << 'EOF'
#!/bin/bash

# SwiftCapture Installation Script

set -e

BINARY_NAME="scap"
INSTALL_DIR="/usr/local/bin"

echo "🚀 Installing SwiftCapture..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ Error: Do not run this script as root (sudo)"
    exit 1
fi

# Check if binary exists
if [ ! -f "$BINARY_NAME" ]; then
    echo "❌ Error: $BINARY_NAME binary not found in current directory"
    exit 1
fi

# Create install directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📁 Creating $INSTALL_DIR directory..."
    sudo mkdir -p "$INSTALL_DIR"
fi

# Copy binary
echo "📦 Installing $BINARY_NAME to $INSTALL_DIR..."
sudo cp "$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Verify installation
if command -v "$BINARY_NAME" &> /dev/null; then
    echo "✅ Installation successful!"
    echo ""
    echo "Usage: $BINARY_NAME --help"
    echo ""
    echo "⚠️  Important: You need to grant Screen Recording permission:"
    echo "   1. Open System Preferences > Security & Privacy > Privacy"
    echo "   2. Select 'Screen Recording' from the left sidebar"
    echo "   3. Add your terminal application and enable it"
    echo "   4. Restart your terminal"
else
    echo "❌ Installation failed: $BINARY_NAME not found in PATH"
    exit 1
fi
EOF

chmod +x "$RELEASE_DIR/install.sh"

# Create uninstall script
cat > "$RELEASE_DIR/uninstall.sh" << 'EOF'
#!/bin/bash

# SwiftCapture Uninstallation Script

BINARY_NAME="scap"
INSTALL_DIR="/usr/local/bin"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"

echo "🗑️  Uninstalling SwiftCapture..."

if [ -f "$BINARY_PATH" ]; then
    sudo rm "$BINARY_PATH"
    echo "✅ SwiftCapture uninstalled successfully"
else
    echo "⚠️  SwiftCapture not found at $BINARY_PATH"
fi
EOF

chmod +x "$RELEASE_DIR/uninstall.sh"

# Create README for release
cat > "$RELEASE_DIR/README.txt" << EOF
SwiftCapture v${VERSION} - Release Package
==========================================

This package contains the SwiftCapture binary and installation scripts.

Files:
- scap: The main executable
- install.sh: Installation script (copies to /usr/local/bin)
- uninstall.sh: Uninstallation script
- README.txt: This file

Installation:
1. Run: ./install.sh
2. Grant Screen Recording permission in System Preferences
3. Use: scap --help

Manual Installation:
1. Copy 'scap' to a directory in your PATH
2. Make it executable: chmod +x scap

System Requirements:
- macOS 12.3 or later
- Screen Recording permission
- Microphone permission (optional, for --enable-microphone)

For more information, visit: https://github.com/GlennWong/SwiftCapture
EOF

# Generate checksums
echo -e "${YELLOW}🔐 Generating checksums...${NC}"
cd "$RELEASE_DIR"
shasum -a 256 "$BINARY_NAME" > "${BINARY_NAME}.sha256"
shasum -a 512 "$BINARY_NAME" > "${BINARY_NAME}.sha512"
cd ..

# Create archive
echo -e "${YELLOW}📦 Creating release archive...${NC}"
ARCHIVE_NAME="scap-v${VERSION}-macos.tar.gz"
tar -czf "$ARCHIVE_NAME" -C "$RELEASE_DIR" .

ARCHIVE_SIZE=$(du -h "$ARCHIVE_NAME" | cut -f1)
ARCHIVE_PATH=$(realpath "$ARCHIVE_NAME")

echo -e "${GREEN}✅ Release package created:${NC}"
echo -e "   📦 Archive: $ARCHIVE_PATH"
echo -e "   📏 Size: $ARCHIVE_SIZE"

# Generate final checksums for archive
echo -e "${YELLOW}🔐 Generating archive checksums...${NC}"
shasum -a 256 "$ARCHIVE_NAME" > "${ARCHIVE_NAME}.sha256"

# Display final summary
echo -e "${GREEN}"
echo "🎉 Release build completed successfully!"
echo "=================================="
echo "Version: $VERSION"
echo "Binary: $BINARY_PATH ($BINARY_SIZE)"
echo "Archive: $ARCHIVE_PATH ($ARCHIVE_SIZE)"
echo ""
echo "Next steps:"
echo "1. Test the binary on clean macOS systems"
echo "2. Update Homebrew formula with correct SHA256"
echo "3. Create GitHub release with the archive"
echo "4. Submit to Homebrew tap"
echo -e "${NC}"

# Show SHA256 for Homebrew formula
echo -e "${BLUE}📋 SHA256 for Homebrew formula:${NC}"
cat "${ARCHIVE_NAME}.sha256"