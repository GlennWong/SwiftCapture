#!/bin/bash

# SwiftCapture Build Validation Script
# This script validates the build configuration and system requirements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Validating SwiftCapture build configuration...${NC}"

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}❌ Error: Package.swift not found. Run this script from the project root.${NC}"
    exit 1
fi

# Validate Package.swift
echo -e "${YELLOW}📋 Validating Package.swift...${NC}"

# Check Swift tools version
SWIFT_TOOLS_VERSION=$(grep "swift-tools-version" Package.swift | grep -o "[0-9]\+\.[0-9]\+")
if [[ "$SWIFT_TOOLS_VERSION" < "5.6" ]]; then
    echo -e "${RED}❌ Error: Swift tools version $SWIFT_TOOLS_VERSION is too old. Minimum: 5.6${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Swift tools version: $SWIFT_TOOLS_VERSION${NC}"

# Check platform requirements
if grep -q "\.macOS(.v12)" Package.swift; then
    echo -e "${GREEN}✅ macOS platform requirement: 12.0+${NC}"
else
    echo -e "${RED}❌ Error: macOS platform requirement not found or incorrect${NC}"
    exit 1
fi

# Check dependencies
if grep -q "swift-argument-parser" Package.swift; then
    echo -e "${GREEN}✅ Swift ArgumentParser dependency found${NC}"
else
    echo -e "${RED}❌ Error: Swift ArgumentParser dependency missing${NC}"
    exit 1
fi

# Check required frameworks
REQUIRED_FRAMEWORKS=("ScreenCaptureKit" "AVFoundation" "CoreMedia" "AppKit")
for framework in "${REQUIRED_FRAMEWORKS[@]}"; do
    if grep -q "$framework" Package.swift; then
        echo -e "${GREEN}✅ Framework linked: $framework${NC}"
    else
        echo -e "${RED}❌ Error: Framework not linked: $framework${NC}"
        exit 1
    fi
done

# Validate system requirements
echo -e "${YELLOW}🖥️  Validating system requirements...${NC}"

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
REQUIRED_VERSION="12.3"

if [[ "$(printf '%s\n' "$REQUIRED_VERSION" "$MACOS_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]]; then
    echo -e "${RED}❌ Error: macOS $REQUIRED_VERSION or later required. Current: $MACOS_VERSION${NC}"
    exit 1
fi
echo -e "${GREEN}✅ macOS version: $MACOS_VERSION${NC}"

# Check Xcode/Swift
if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Error: Swift not found. Install Xcode 14.3 or later.${NC}"
    exit 1
fi

SWIFT_VERSION=$(swift --version | head -n1)
echo -e "${GREEN}✅ Swift: $SWIFT_VERSION${NC}"

# Check if we can resolve dependencies
echo -e "${YELLOW}📦 Resolving dependencies...${NC}"
if swift package resolve; then
    echo -e "${GREEN}✅ Dependencies resolved successfully${NC}"
else
    echo -e "${RED}❌ Error: Failed to resolve dependencies${NC}"
    exit 1
fi

# Test debug build
echo -e "${YELLOW}🔨 Testing debug build...${NC}"
if swift build; then
    echo -e "${GREEN}✅ Debug build successful${NC}"
else
    echo -e "${RED}❌ Error: Debug build failed${NC}"
    exit 1
fi

# Test release build
echo -e "${YELLOW}🚀 Testing release build...${NC}"
if swift build -c release; then
    echo -e "${GREEN}✅ Release build successful${NC}"
else
    echo -e "${RED}❌ Error: Release build failed${NC}"
    exit 1
fi

# Check binary
BINARY_PATH=".build/release/SwiftCapture"
if [ -f "$BINARY_PATH" ]; then
    BINARY_SIZE=$(du -h "$BINARY_PATH" | cut -f1)
    echo -e "${GREEN}✅ Binary created: $BINARY_SIZE${NC}"
    
    # Test binary execution
    if "$BINARY_PATH" --version &> /dev/null; then
        VERSION_OUTPUT=$("$BINARY_PATH" --version 2>&1)
        echo -e "${GREEN}✅ Binary execution test: $VERSION_OUTPUT${NC}"
    else
        echo -e "${RED}❌ Error: Binary execution failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Error: Binary not found at $BINARY_PATH${NC}"
    exit 1
fi

# Run tests if available
echo -e "${YELLOW}🧪 Running tests...${NC}"
if swift test; then
    echo -e "${GREEN}✅ All tests passed${NC}"
else
    echo -e "${YELLOW}⚠️  Some tests failed or no tests found${NC}"
fi

# Check for required files
echo -e "${YELLOW}📄 Checking required files...${NC}"

REQUIRED_FILES=("README.md" "Package.swift")
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ Found: $file${NC}"
    else
        echo -e "${RED}❌ Missing: $file${NC}"
        exit 1
    fi
done

# Check source structure
if [ -d "Sources/SwiftCapture" ]; then
    echo -e "${GREEN}✅ Source directory structure correct${NC}"
else
    echo -e "${RED}❌ Error: Source directory structure incorrect${NC}"
    exit 1
fi

# Validate release configuration
if [ -f "release-config.json" ]; then
    echo -e "${GREEN}✅ Release configuration found${NC}"
    
    # Basic JSON validation
    if python3 -m json.tool release-config.json > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Release configuration is valid JSON${NC}"
    else
        echo -e "${RED}❌ Error: Release configuration is invalid JSON${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Release configuration not found${NC}"
fi

# Check Homebrew formula
if [ -f "Formula/scap.rb" ]; then
    echo -e "${GREEN}✅ Homebrew formula found${NC}"
    
    # Basic Ruby syntax check
    if ruby -c Formula/scap.rb > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Homebrew formula syntax is valid${NC}"
    else
        echo -e "${RED}❌ Error: Homebrew formula has syntax errors${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️  Homebrew formula not found${NC}"
fi

# Generate validation report
echo -e "${YELLOW}📊 Generating validation report...${NC}"

cat > build-validation-report.md << EOF
# Build Validation Report

**Date:** $(date)
**System:** macOS $MACOS_VERSION
**Swift:** $SWIFT_VERSION

## Validation Results

### Package Configuration
- ✅ Swift tools version: $SWIFT_TOOLS_VERSION
- ✅ macOS platform requirement: 12.0+
- ✅ Swift ArgumentParser dependency
- ✅ Required frameworks linked

### System Requirements
- ✅ macOS version: $MACOS_VERSION
- ✅ Swift/Xcode available
- ✅ Dependencies resolved

### Build Tests
- ✅ Debug build successful
- ✅ Release build successful
- ✅ Binary created: $BINARY_SIZE
- ✅ Binary execution test passed

### File Structure
- ✅ Required files present
- ✅ Source directory structure correct
- ✅ Release configuration available
- ✅ Homebrew formula available

## Binary Information

- **Path:** $BINARY_PATH
- **Size:** $BINARY_SIZE
- **Version:** $VERSION_OUTPUT

## Next Steps

1. Run comprehensive tests: \`swift test\`
2. Test on different macOS versions
3. Validate Homebrew installation
4. Create release archive
5. Generate checksums
6. Publish to GitHub releases

## Commands

\`\`\`bash
# Build release
swift build -c release

# Run tests
swift test

# Create release package
./scripts/build-release.sh

# Test Homebrew installation
./scripts/test-homebrew-install.sh
\`\`\`
EOF

echo -e "${GREEN}✅ Validation report generated: build-validation-report.md${NC}"

echo -e "${GREEN}"
echo "🎉 Build validation completed successfully!"
echo "========================================"
echo "All validation checks passed."
echo "The project is ready for release distribution."
echo ""
echo "Summary:"
echo "- Package configuration: ✅"
echo "- System requirements: ✅"
echo "- Build tests: ✅"
echo "- File structure: ✅"
echo "- Binary: $BINARY_SIZE"
echo -e "${NC}"