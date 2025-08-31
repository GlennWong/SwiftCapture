#!/bin/bash

# SwiftCapture Release Automation Script
# This script is designed to be triggered by GitHub Actions when a release is created

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 SwiftCapture Release Automation${NC}"

# Get version from environment or git tag
if [ -n "$GITHUB_REF" ]; then
    VERSION=${GITHUB_REF#refs/tags/v}
elif [ -n "$1" ]; then
    VERSION=$1
else
    echo -e "${RED}❌ Error: No version specified${NC}"
    echo "Usage: $0 <version>"
    echo "Example: $0 2.1.9"
    exit 1
fi

echo -e "${YELLOW}📋 Building SwiftCapture v$VERSION${NC}"

# Update version in release config
echo -e "${YELLOW}📝 Updating release configuration...${NC}"
jq ".version = \"$VERSION\"" release-config.json > tmp.json && mv tmp.json release-config.json

# Build release for both architectures
echo -e "${YELLOW}🔨 Building universal binary (Intel + Apple Silicon)...${NC}"

# Build for arm64 (Apple Silicon)
echo -e "${YELLOW}  📱 Building for arm64 (Apple Silicon)...${NC}"
swift build -c release --disable-sandbox --arch arm64

# Build for x86_64 (Intel)
echo -e "${YELLOW}  💻 Building for x86_64 (Intel)...${NC}"
swift build -c release --disable-sandbox --arch x86_64

# Check if both builds were successful
if [ ! -f ".build/arm64-apple-macosx/release/SwiftCapture" ]; then
    echo -e "${RED}❌ ARM64 build failed: Binary not found${NC}"
    exit 1
fi

if [ ! -f ".build/x86_64-apple-macosx/release/SwiftCapture" ]; then
    echo -e "${RED}❌ x86_64 build failed: Binary not found${NC}"
    exit 1
fi

# Create universal binary using lipo
echo -e "${YELLOW}  🔗 Creating universal binary...${NC}"
mkdir -p release
lipo -create \
    .build/arm64-apple-macosx/release/SwiftCapture \
    .build/x86_64-apple-macosx/release/SwiftCapture \
    -output release/scap

chmod +x release/scap

# Verify universal binary
echo -e "${YELLOW}🔍 Verifying universal binary...${NC}"
file release/scap
lipo -info release/scap

# Test the binary
echo -e "${YELLOW}🧪 Testing binary...${NC}"
if ! release/scap --version &> /dev/null; then
    echo -e "${RED}❌ Binary test failed${NC}"
    exit 1
fi

# Create installation files
echo -e "${YELLOW}📦 Creating installation package...${NC}"

# Create installation script
cat > release/install.sh << 'EOF'
#!/bin/bash
set -e
BINARY_NAME="scap"
INSTALL_DIR="/usr/local/bin"
echo "🚀 Installing SwiftCapture..."
if [[ $EUID -eq 0 ]]; then
    echo "❌ Error: Do not run this script as root (sudo)"
    exit 1
fi
if [ ! -f "$BINARY_NAME" ]; then
    echo "❌ Error: $BINARY_NAME binary not found in current directory"
    exit 1
fi
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📁 Creating $INSTALL_DIR directory..."
    sudo mkdir -p "$INSTALL_DIR"
fi
echo "📦 Installing $BINARY_NAME to $INSTALL_DIR..."
sudo cp "$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
sudo chmod +x "$INSTALL_DIR/$BINARY_NAME"
if command -v "$BINARY_NAME" &> /dev/null; then
    echo "✅ Installation successful!"
    echo "Usage: $BINARY_NAME --help"
    echo "⚠️  Important: Grant Screen Recording permission in System Preferences"
else
    echo "❌ Installation failed"
    exit 1
fi
EOF

chmod +x release/install.sh

# Create README
cat > release/README.txt << EOF
SwiftCapture v${VERSION} - Release Package (Universal Binary)
=============================================================

Professional screen recording tool for macOS with comprehensive CLI interface.
This is a Universal Binary that supports both Intel and Apple Silicon Macs.

Files:
- scap: The main executable (Universal Binary)
- install.sh: Installation script
- README.txt: This file

Installation via Homebrew (Recommended):
brew tap GlennWong/swiftcapture
brew install swiftcapture

Manual Installation:
1. Run: ./install.sh
2. Grant Screen Recording permission in System Preferences

System Requirements:
- macOS 12.3 (Monterey) or later
- Intel or Apple Silicon Mac (Universal Binary)
- Screen Recording permission
- Microphone permission (optional)

Usage:
scap --help                    # Show help
scap --screen-list            # List available screens
scap --duration 5000          # Record for 5 seconds
scap --output recording.mov   # Specify output file

For more information: https://github.com/GlennWong/SwiftCapture
EOF

# Create archive
ARCHIVE_NAME="scap-v${VERSION}-macos.tar.gz"
echo -e "${YELLOW}📦 Creating archive: $ARCHIVE_NAME${NC}"
tar -czf "$ARCHIVE_NAME" -C release .

# Generate checksums
echo -e "${YELLOW}🔐 Generating checksums...${NC}"
SHA256=$(shasum -a 256 "$ARCHIVE_NAME" | cut -d' ' -f1)
echo "$SHA256  $ARCHIVE_NAME" > "${ARCHIVE_NAME}.sha256"

# Update Homebrew formula
echo -e "${YELLOW}📝 Updating Homebrew formula...${NC}"
cat > swiftcapture.rb << EOF
class Swiftcapture < Formula
  desc "Professional screen recording tool for macOS with comprehensive CLI interface (Universal Binary)"
  homepage "https://github.com/GlennWong/SwiftCapture"
  url "https://github.com/GlennWong/SwiftCapture/releases/download/v${VERSION}/scap-v${VERSION}-macos.tar.gz"
  sha256 "${SHA256}"
  license "MIT"
  version "${VERSION}"

  # System requirements - Universal Binary supports both Intel and Apple Silicon
  depends_on :macos => :monterey # macOS 12.3+

  def install
    # Install the binary
    bin.install "scap"
    
    # Install documentation if present
    if File.exist?("README.txt")
      doc.install "README.txt"
    end
  end

  def caveats
    <<~EOS
      SwiftCapture requires Screen Recording permission to function properly.
      
      To grant permission:
      1. Open System Preferences > Security & Privacy > Privacy
      2. Select 'Screen Recording' from the left sidebar  
      3. Click the lock to make changes (enter your password)
      4. Add your terminal application (Terminal.app, iTerm2, etc.)
      5. Enable the checkbox for your terminal
      6. Restart your terminal application
      
      For microphone recording, also grant Microphone permission in the same way.
      
      Usage examples:
        scap --help                    # Show help
        scap --screen-list            # List available screens
        scap --duration 5000          # Record for 5 seconds
        scap --output recording.mov   # Specify output file
    EOS
  end

  test do
    # Test that the binary exists and is executable
    assert_predicate bin/"scap", :exist?
    assert_predicate bin/"scap", :executable?
    
    # Test version command
    system bin/"scap", "--version"
    
    # Test help command  
    system bin/"scap", "--help"
    
    # Test screen list (may fail without permissions, but shouldn't crash)
    system bin/"scap", "--screen-list" rescue nil
    
    # Test app list
    system bin/"scap", "--app-list" rescue nil
    
    # Test preset list
    system bin/"scap", "--list-presets"
  end
end
EOF

# Display results
echo -e "${GREEN}"
echo "🎉 Release automation completed!"
echo "================================"
echo "Version: $VERSION"
echo "Archive: $ARCHIVE_NAME"
echo "SHA256: $SHA256"
echo ""
echo "Files created:"
echo "- $ARCHIVE_NAME (release archive)"
echo "- ${ARCHIVE_NAME}.sha256 (checksum)"
echo "- swiftcapture.rb (Homebrew formula)"
echo ""
echo "Next: GitHub Actions will upload these files and update the tap repository"
echo -e "${NC}"