#!/bin/bash

# SwiftCapture Homebrew Release Preparation Script
# This script prepares everything needed for Homebrew distribution

set -e

# Configuration
HOMEBREW_TAP_DIR="../homebrew-swiftcapture"
FORMULA_DIR="$HOMEBREW_TAP_DIR/Formula"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🍺 Preparing SwiftCapture for Homebrew release...${NC}"

# Step 1: Build release
echo -e "${YELLOW}🔨 Step 1: Building release...${NC}"
if [ ! -f "scripts/build-release.sh" ]; then
    echo -e "${RED}❌ Error: build-release.sh not found${NC}"
    exit 1
fi

./scripts/build-release.sh

# Step 2: Update formula
echo -e "${YELLOW}📝 Step 2: Updating Homebrew formula...${NC}"
./scripts/update-homebrew-formula.sh

# Step 3: Check if tap repository exists (optional for local testing)
echo -e "${YELLOW}📁 Step 3: Checking Homebrew tap repository...${NC}"
if [ -d "$HOMEBREW_TAP_DIR" ]; then
    echo -e "${GREEN}✅ Tap repository found at $HOMEBREW_TAP_DIR${NC}"
    
    # Step 4: Copy formula to tap (for local testing)
    echo -e "${YELLOW}📋 Step 4: Copying generated formula to tap repository...${NC}"
    mkdir -p "$FORMULA_DIR"
    if [ -f "swiftcapture.rb" ]; then
        cp swiftcapture.rb "$FORMULA_DIR/"
        echo -e "${GREEN}✅ Formula copied to $FORMULA_DIR/swiftcapture.rb${NC}"
    else
        echo -e "${YELLOW}⚠️  Formula not found (will be generated during release)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Homebrew tap directory not found at $HOMEBREW_TAP_DIR${NC}"
    echo -e "${BLUE}💡 This is normal for CI/CD. The GitHub Actions workflow will handle the tap update.${NC}"
fi

# Step 5: Extract version and archive info
VERSION=$(jq -r '.version' release-config.json)
ARCHIVE_NAME="scap-v${VERSION}-macos.tar.gz"
SHA256=$(shasum -a 256 "$ARCHIVE_NAME" | cut -d' ' -f1)

# Step 6: Display final instructions
echo -e "${GREEN}"
echo "🎉 Homebrew release preparation completed!"
echo "========================================"
echo ""
echo "📦 Release Information:"
echo "   Version: $VERSION"
echo "   Archive: $ARCHIVE_NAME"
echo "   SHA256: $SHA256"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Create GitHub Release:"
echo "   - Go to: https://github.com/GlennWong/SwiftCapture/releases/new"
echo "   - Tag: v$VERSION"
echo "   - Title: SwiftCapture v$VERSION"
echo "   - Upload: $ARCHIVE_NAME"
echo "   - Publish release"
echo ""
echo "2. Create GitHub Release (this will trigger automatic tap update):"
echo "   gh release create v$VERSION --title \"v$VERSION\" --notes \"Release notes here\""
echo ""
echo "   Or manually update Homebrew Tap Repository:"
echo "   cd $HOMEBREW_TAP_DIR"
echo "   git add ."
echo "   git commit -m \"Update SwiftCapture to v$VERSION\""
echo "   git push origin main"
echo ""
echo "3. Test Installation:"
echo "   brew tap GlennWong/swiftcapture"
echo "   brew install swiftcapture"
echo "   scap --version"
echo ""
echo "4. Optional - Submit to Homebrew Core:"
echo "   # After testing, you can submit to the main Homebrew repository"
echo "   # This makes it available as just 'brew install swiftcapture'"
echo -e "${NC}"

# Step 7: Create quick test script
cat > "test-homebrew-install.sh" << EOF
#!/bin/bash

# Quick test script for Homebrew installation

echo "🧪 Testing Homebrew installation..."

# Remove any existing installation
brew uninstall swiftcapture 2>/dev/null || true
brew untap GlennWong/swiftcapture 2>/dev/null || true

# Install from tap
echo "📥 Installing from tap..."
brew tap GlennWong/swiftcapture
brew install swiftcapture

# Test installation
echo "🔍 Testing installation..."
if command -v scap &> /dev/null; then
    echo "✅ scap command found"
    scap --version
    scap --help | head -5
    echo "✅ Installation test passed"
else
    echo "❌ Installation test failed"
    exit 1
fi
EOF

chmod +x test-homebrew-install.sh

echo -e "${BLUE}💡 Created test-homebrew-install.sh for quick testing${NC}"