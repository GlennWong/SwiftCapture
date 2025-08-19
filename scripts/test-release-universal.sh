#!/bin/bash

# Test Release Process with Universal Binary
# This script tests the complete release process locally

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing Complete Release Process (Universal Binary)${NC}"

# Test version
TEST_VERSION="2.1.10-test"

# Clean up any previous test files
echo -e "${YELLOW}🧹 Cleaning up previous test files...${NC}"
rm -f scap-v${TEST_VERSION}-macos.tar.gz*
rm -f swiftcapture.rb
rm -rf release/

# Run the release automation script
echo -e "${YELLOW}🚀 Running release automation...${NC}"
./scripts/release-automation.sh $TEST_VERSION

# Verify the created files
echo -e "${YELLOW}🔍 Verifying created files...${NC}"

ARCHIVE_NAME="scap-v${TEST_VERSION}-macos.tar.gz"

if [ ! -f "$ARCHIVE_NAME" ]; then
    echo -e "${RED}❌ Archive not created: $ARCHIVE_NAME${NC}"
    exit 1
fi

if [ ! -f "${ARCHIVE_NAME}.sha256" ]; then
    echo -e "${RED}❌ Checksum file not created${NC}"
    exit 1
fi

if [ ! -f "swiftcapture.rb" ]; then
    echo -e "${RED}❌ Homebrew formula not created${NC}"
    exit 1
fi

# Test the archive
echo -e "${YELLOW}📦 Testing archive contents...${NC}"
mkdir -p test-extract
tar -xzf "$ARCHIVE_NAME" -C test-extract

if [ ! -f "test-extract/scap" ]; then
    echo -e "${RED}❌ Binary not found in archive${NC}"
    exit 1
fi

if [ ! -f "test-extract/install.sh" ]; then
    echo -e "${RED}❌ Install script not found in archive${NC}"
    exit 1
fi

# Verify the binary is universal
echo -e "${YELLOW}🔍 Verifying binary architecture...${NC}"
ARCH_INFO=$(lipo -info test-extract/scap)
echo "Architecture info: $ARCH_INFO"

if [[ "$ARCH_INFO" != *"x86_64"* ]] || [[ "$ARCH_INFO" != *"arm64"* ]]; then
    echo -e "${RED}❌ Binary is not universal (missing x86_64 or arm64)${NC}"
    exit 1
fi

# Test binary functionality
echo -e "${YELLOW}🧪 Testing binary functionality...${NC}"
if test-extract/scap --version &> /dev/null; then
    echo -e "${GREEN}✅ Binary test passed${NC}"
else
    echo -e "${RED}❌ Binary test failed${NC}"
    exit 1
fi

# Verify Homebrew formula
echo -e "${YELLOW}📝 Verifying Homebrew formula...${NC}"
if grep -q "Universal Binary" swiftcapture.rb; then
    echo -e "${GREEN}✅ Formula mentions Universal Binary${NC}"
else
    echo -e "${RED}❌ Formula doesn't mention Universal Binary${NC}"
    exit 1
fi

if grep -q "depends_on arch: \[:arm64, :x86_64\]" swiftcapture.rb; then
    echo -e "${GREEN}✅ Formula supports both architectures${NC}"
else
    echo -e "${RED}❌ Formula doesn't support both architectures${NC}"
    exit 1
fi

# Clean up test files
echo -e "${YELLOW}🧹 Cleaning up test files...${NC}"
rm -f scap-v${TEST_VERSION}-macos.tar.gz*
rm -f swiftcapture.rb
rm -rf release/
rm -rf test-extract/

echo -e "${GREEN}🎉 All tests passed! Release process is ready for universal binary distribution.${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "✅ Universal binary creation works"
echo "✅ Archive packaging works"
echo "✅ Homebrew formula generation works"
echo "✅ Binary functionality verified"
echo "✅ Both Intel and Apple Silicon support confirmed"