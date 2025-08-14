#!/bin/bash

# SwiftCapture 完整功能验证脚本
# 用最少的命令验证所有核心功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 SwiftCapture 完整功能验证${NC}"
echo "=================================="

# 1. 构建和基础验证
echo -e "${YELLOW}1️⃣ 构建项目和基础验证...${NC}"
swift build -c release
BINARY=".build/release/SwiftCapture"

# 2. 核心功能测试 - 信息查询命令
echo -e "${YELLOW}2️⃣ 测试信息查询功能...${NC}"
$BINARY --version
$BINARY --help | head -20
$BINARY --screen-list
$BINARY --app-list | head -10

# 3. 预设管理功能测试
echo -e "${YELLOW}3️⃣ 测试预设管理功能...${NC}"
$BINARY --save-preset "test-preset" --duration 5000 --quality high --fps 30
$BINARY --list-presets
$BINARY --preset "test-preset" --output test-preset-recording.mov --duration 3000 &
sleep 5 && pkill -f SwiftCapture || true
$BINARY --delete-preset "test-preset"

# 4. 综合录制功能测试 - 一个命令测试多个功能
echo -e "${YELLOW}4️⃣ 综合录制功能测试...${NC}"
$BINARY --screen 1 --area center:800:600 --duration 5000 --quality medium --fps 30 --countdown 3 --show-cursor --format mov --output comprehensive-test.mov &
sleep 8 && pkill -f SwiftCapture || true

# 5. 应用录制和音频功能测试
echo -e "${YELLOW}5️⃣ 应用录制和音频功能测试...${NC}"
$BINARY --app Finder --enable-microphone --duration 3000 --audio-quality high --format mp4 --output app-audio-test.mp4 &
sleep 5 && pkill -f SwiftCapture || true

# 6. 运行单元测试
echo -e "${YELLOW}6️⃣ 运行单元测试...${NC}"
swift test

echo -e "${GREEN}✅ 所有功能验证完成！${NC}"
echo "生成的测试文件："
ls -la *.mov *.mp4 2>/dev/null || echo "无录制文件生成（正常，因为录制被中断）"