#!/bin/bash

# Test script to simulate the release flow locally
# Usage: ./scripts/test-release-flow.sh 2.1.9

set -e

VERSION=${1:-"2.1.9"}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 Testing release flow for v$VERSION${NC}"

# Clean up previous test files
echo -e "${YELLOW}🧹 Cleaning up previous test files...${NC}"
rm -f scap-v*-macos.tar.gz*
rm -f swiftcapture.rb
rm -rf release/

# Run the release automation
echo -e "${YELLOW}🚀 Running release automation...${NC}"
./scripts/release-automation.sh $VERSION

# Verify files were created
echo -e "${YELLOW}🔍 Verifying created files...${NC}"
ARCHIVE_NAME="scap-v${VERSION}-macos.tar.gz"

if [ ! -f "$ARCHIVE_NAME" ]; then
    echo -e "${RED}❌ Archive not created: $ARCHIVE_NAME${NC}"
    exit 1
fi

if [ ! -f "${ARCHIVE_NAME}.sha256" ]; then
    echo -e "${RED}❌ Checksum not created: ${ARCHIVE_NAME}.sha256${NC}"
    exit 1
fi

if [ ! -f "swiftcapture.rb" ]; then
    echo -e "${RED}❌ Formula not created: swiftcapture.rb${NC}"
    exit 1
fi

# Test the archive contents
echo -e "${YELLOW}📦 Testing archive contents...${NC}"
mkdir -p test-extract
tar -xzf "$ARCHIVE_NAME" -C test-extract

if [ ! -f "test-extract/scap" ]; then
    echo -e "${RED}❌ Binary not found in archive${NC}"
    exit 1
fi

if [ ! -x "test-extract/scap" ]; then
    echo -e "${RED}❌ Binary is not executable${NC}"
    exit 1
fi

# Test the binary
echo -e "${YELLOW}🧪 Testing extracted binary...${NC}"
if ! test-extract/scap --version &> /dev/null; then
    echo -e "${RED}❌ Binary test failed${NC}"
    exit 1
fi

# Clean up test extraction
rm -rf test-extract

# Display results
echo -e "${GREEN}"
echo "✅ Release flow test completed successfully!"
echo "=========================================="
echo "Version: $VERSION"
echo "Archive: $ARCHIVE_NAME ($(du -h $ARCHIVE_NAME | cut -f1))"
echo "SHA256: $(cat ${ARCHIVE_NAME}.sha256 | cut -d' ' -f1)"
echo ""
echo "Files ready for release:"
echo "- $ARCHIVE_NAME"
echo "- ${ARCHIVE_NAME}.sha256"
echo "- swiftcapture.rb"
echo ""
echo "To create actual release:"
echo "gh release create v$VERSION --title \"v$VERSION\" --notes \"Release notes\" $ARCHIVE_NAME ${ARCHIVE_NAME}.sha256"
echo -e "${NC}"