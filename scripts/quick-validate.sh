#!/bin/bash

# SwiftCapture 快速功能验证 - 仅用3个命令验证所有功能
set -e

echo "🚀 SwiftCapture 快速验证（3个命令）"
echo "=================================="

# 命令1: 构建 + 基础功能验证（版本、帮助、列表功能）
echo "1️⃣ 构建项目并验证基础功能..."
swift build -c release && \
.build/release/SwiftCapture --version && \
.build/release/SwiftCapture --screen-list && \
.build/release/SwiftCapture --app-list | head -5

# 命令2: 综合录制功能验证（屏幕录制 + 区域选择 + 质量设置 + 格式 + 预设管理）
echo "2️⃣ 综合录制功能验证..."
.build/release/SwiftCapture --save-preset "quick-test" --screen 1 --area center:640:480 --duration 2000 --quality high --fps 30 --countdown 1 --show-cursor --format mov --output quick-test.mov && \
.build/release/SwiftCapture --preset "quick-test" --duration 1000 --output preset-test.mov && \
.build/release/SwiftCapture --delete-preset "quick-test"

# 命令3: 单元测试验证（验证所有内部逻辑和边界情况）
echo "3️⃣ 运行完整测试套件..."
swift test

echo "✅ 验证完成！所有核心功能正常工作。"