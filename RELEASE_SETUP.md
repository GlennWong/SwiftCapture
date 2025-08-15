# 自动化发布设置指南

## 🚀 一键发布流程

现在你只需要在 GitHub 上创建一个 Release，剩下的全部自动完成！

### 设置步骤

1. **创建 Personal Access Token**
   - 访问 GitHub Settings > Developer settings > Personal access tokens > Tokens (classic)
   - 点击 "Generate new token (classic)"
   - 选择 scopes: `repo` (完整仓库访问权限)
   - 复制生成的 token

2. **在主项目中添加 Secret**
   - 访问 https://github.com/GlennWong/SwiftCapture/settings/secrets/actions
   - 点击 "New repository secret"
   - Name: `HOMEBREW_TAP_TOKEN`
   - Value: 粘贴上面创建的 token
   - 点击 "Add secret"

3. **确保 GitHub Actions 权限**
   - 访问 https://github.com/GlennWong/SwiftCapture/settings/actions
   - 在 "Workflow permissions" 部分选择 "Read and write permissions"
   - 勾选 "Allow GitHub Actions to create and approve pull requests"
   - 点击 "Save"

### 发布流程

1. **创建 Release**
   - 访问 https://github.com/GlennWong/SwiftCapture/releases/new
   - Tag version: `v2.1.2` (或任何新版本)
   - Release title: `SwiftCapture v2.1.2`
   - Release notes: 描述更新内容
   - 点击 "Publish release"

2. **自动化完成**
   - ✅ 自动更新源代码版本号
   - ✅ 自动计算 SHA256 哈希
   - ✅ 自动更新 Homebrew Formula
   - ✅ 自动推送到 homebrew-swiftcapture 仓库

3. **验证安装**
   ```bash
   brew untap GlennWong/swiftcapture
   brew tap GlennWong/swiftcapture
   brew install swiftcapture
   scap --version
   ```

### GitHub Actions 工作流

已创建 `.github/workflows/release.yml` 文件，当你发布 Release 时会自动触发。

## 优势

- ✅ **免费**: 使用 GitHub Actions，完全免费
- ✅ **简单**: 只需创建 GitHub Release
- ✅ **最佳实践**: 遵循 GitHub 和 Homebrew 标准
- ✅ **自动化**: 无需手动操作任何步骤
- ✅ **可靠**: 自动处理版本号和哈希计算

**就这么简单！** 🎉