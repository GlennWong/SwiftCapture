#!/bin/bash

# SwiftCapture Homebrew Formula Update Script
# This script updates the Homebrew formula with the latest release information

set -e

# Configuration
FORMULA_FILE="swiftcapture.rb"
RELEASE_CONFIG="release-config.json"
HOMEBREW_TAP_REPO="homebrew-swiftcapture"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🍺 Updating Homebrew formula...${NC}"

# Check if release config exists
if [ ! -f "$RELEASE_CONFIG" ]; then
    echo -e "${RED}❌ Error: $RELEASE_CONFIG not found${NC}"
    exit 1
fi

# Extract version from release config
VERSION=$(jq -r '.version' "$RELEASE_CONFIG")
if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
    echo -e "${RED}❌ Error: Could not extract version from $RELEASE_CONFIG${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Version: $VERSION${NC}"

# Check if archive exists
ARCHIVE_NAME="scap-v${VERSION}-macos.tar.gz"
if [ ! -f "$ARCHIVE_NAME" ]; then
    echo -e "${RED}❌ Error: Release archive $ARCHIVE_NAME not found${NC}"
    echo -e "${YELLOW}💡 Run ./scripts/build-release.sh first${NC}"
    exit 1
fi

# Calculate SHA256
echo -e "${YELLOW}🔐 Calculating SHA256...${NC}"
SHA256=$(shasum -a 256 "$ARCHIVE_NAME" | cut -d' ' -f1)
echo -e "${GREEN}✅ SHA256: $SHA256${NC}"

# Update formula file
echo -e "${YELLOW}📝 Updating formula file...${NC}"

# Create updated formula
cat > "$FORMULA_FILE" << EOF
class Swiftcapture < Formula
  desc "Professional screen recording tool for macOS with comprehensive CLI interface"
  homepage "https://github.com/GlennWong/SwiftCapture"
  url "https://github.com/GlennWong/SwiftCapture/releases/download/v${VERSION}/scap-v${VERSION}-macos.tar.gz"
  sha256 "${SHA256}"
  license "MIT"
  version "${VERSION}"

  # System requirements
  depends_on :macos => :monterey # macOS 12.3+
  depends_on arch: [:arm64, :x86_64]

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

echo -e "${GREEN}✅ Formula updated successfully${NC}"

# Display next steps
echo -e "${BLUE}"
echo "📋 Next steps:"
echo "=============="
echo "1. Create GitHub release with the archive:"
echo "   - Upload: $ARCHIVE_NAME"
echo "   - Tag: v$VERSION"
echo ""
echo "2. Update Homebrew tap repository:"
echo "   - Copy $FORMULA_FILE to $HOMEBREW_TAP_REPO/Formula/"
echo "   - Commit and push changes"
echo ""
echo "3. Test installation:"
echo "   brew tap GlennWong/swiftcapture"
echo "   brew install swiftcapture"
echo ""
echo "4. Formula details:"
echo "   Version: $VERSION"
echo "   SHA256: $SHA256"
echo "   URL: https://github.com/GlennWong/SwiftCapture/releases/download/v${VERSION}/scap-v${VERSION}-macos.tar.gz"
echo -e "${NC}"