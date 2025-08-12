#!/bin/bash

# SwiftCapture Release Script
# 自动化版本发布和Formula更新流程

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数定义
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查参数
if [ $# -ne 1 ]; then
    log_error "Usage: $0 <version>"
    log_info "Example: $0 v2.0.1"
    exit 1
fi

VERSION=$1
ARCHIVE_URL="https://github.com/GlennWong/SwiftCapture/archive/${VERSION}.tar.gz"

log_info "开始发布 SwiftCapture ${VERSION}"

# 1. 检查工作目录是否干净
if [ -n "$(git status --porcelain)" ]; then
    log_warning "工作目录有未提交的更改"
    git status --short
    read -p "是否继续？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "发布已取消"
        exit 1
    fi
fi

# 2. 创建并推送标签
log_info "创建标签 ${VERSION}"
git tag ${VERSION}

log_info "推送标签到远程仓库"
git push origin ${VERSION}

# 3. 等待GitHub处理标签
log_info "等待GitHub处理新标签..."
sleep 10

# 4. 获取SHA256哈希
log_info "获取归档文件的SHA256哈希值"
SHA256=$(curl -sL ${ARCHIVE_URL} | shasum -a 256 | cut -d' ' -f1)

if [ -z "$SHA256" ]; then
    log_error "无法获取SHA256哈希值"
    exit 1
fi

log_success "SHA256: ${SHA256}"

# 5. 更新Formula文件
log_info "更新Formula文件"

# 更新主Formula
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" Formula/swiftcapture.rb
sed -i '' "s|url \".*\"|url \"${ARCHIVE_URL}\"|" Formula/swiftcapture.rb

# 更新homebrew-tap Formula
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" homebrew-tap/Formula/swiftcapture.rb
sed -i '' "s|url \".*\"|url \"${ARCHIVE_URL}\"|" homebrew-tap/Formula/swiftcapture.rb

log_success "Formula文件已更新"

# 6. 测试Formula
log_info "测试Formula安装"
if brew install --build-from-source ./Formula/swiftcapture.rb; then
    log_success "Formula测试通过"
    brew uninstall swiftcapture
else
    log_error "Formula测试失败"
    exit 1
fi

# 7. 提交更改
log_info "提交Formula更新"
git add Formula/swiftcapture.rb homebrew-tap/Formula/swiftcapture.rb
git commit -m "Release ${VERSION}: Update SHA256 and URL"
git push

# 8. 更新homebrew-tap仓库（如果存在）
if [ -d "homebrew-tap/.git" ]; then
    log_info "更新homebrew-tap仓库"
    cd homebrew-tap
    git add .
    git commit -m "Release ${VERSION}: Update formula"
    git push
    cd ..
fi

log_success "🎉 发布 ${VERSION} 完成！"
log_info "用户现在可以通过以下方式安装："
echo "  brew install --build-from-source ./Formula/swiftcapture.rb"
echo "  或者（如果设置了tap）："
echo "  brew tap GlennWong/swiftcapture"
echo "  brew install swiftcapture"