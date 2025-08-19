#!/bin/bash

# Test Universal Binary Build Script
# This script tests the universal binary creation process locally

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing Universal Binary Build${NC}"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
swift package clean

# Build for both architectures
echo -e "${YELLOW}🔨 Building for arm64...${NC}"
swift build -c release --disable-sandbox --arch arm64

echo -e "${YELLOW}🔨 Building for x86_64...${NC}"
swift build -c release --disable-sandbox --arch x86_64

# Check if both builds exist
if [ ! -f ".build/arm64-apple-macosx/release/SwiftCapture" ]; then
    echo -e "${RED}❌ ARM64 build not found${NC}"
    exit 1
fi

if [ ! -f ".build/x86_64-apple-macosx/release/SwiftCapture" ]; then
    echo -e "${RED}❌ x86_64 build not found${NC}"
    exit 1
fi

# Create universal binary
echo -e "${YELLOW}🔗 Creating universal binary...${NC}"
mkdir -p test-release
lipo -create \
    .build/arm64-apple-macosx/release/SwiftCapture \
    .build/x86_64-apple-macosx/release/SwiftCapture \
    -output test-release/scap

chmod +x test-release/scap

# Verify the binary
echo -e "${YELLOW}🔍 Verifying universal binary...${NC}"
echo "File info:"
file test-release/scap
echo ""
echo "Architecture info:"
lipo -info test-release/scap
echo ""

# Test the binary
echo -e "${YELLOW}🧪 Testing binary functionality...${NC}"
if test-release/scap --version &> /dev/null; then
    echo -e "${GREEN}✅ Binary test passed${NC}"
else
    echo -e "${RED}❌ Binary test failed${NC}"
    exit 1
fi

# Show size comparison
echo -e "${YELLOW}📊 Size comparison:${NC}"
echo "ARM64 binary: $(ls -lh .build/arm64-apple-macosx/release/SwiftCapture | awk '{print $5}')"
echo "x86_64 binary: $(ls -lh .build/x86_64-apple-macosx/release/SwiftCapture | awk '{print $5}')"
echo "Universal binary: $(ls -lh test-release/scap | awk '{print $5}')"

echo -e "${GREEN}🎉 Universal binary test completed successfully!${NC}"
echo "Universal binary created at: test-release/scap"