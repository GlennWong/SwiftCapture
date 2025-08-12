# 提交SwiftCapture到Homebrew Core指南

## 要求检查清单

### ✅ 已满足的要求：
- [x] 开源项目（MIT许可证）
- [x] 稳定的版本标签（v2.0.0）
- [x] 可构建的源代码
- [x] 适当的文档

### 🔄 需要完善的要求：

#### 1. 项目成熟度
- [ ] 至少30个GitHub stars
- [ ] 活跃的维护（定期提交）
- [ ] 用户反馈和issue处理

#### 2. 包质量
- [ ] 全面的测试覆盖
- [ ] CI/CD流水线
- [ ] 详细的文档

#### 3. Homebrew特定要求
- [ ] Formula必须构建成功
- [ ] 通过所有Homebrew测试
- [ ] 遵循Homebrew命名约定

## 提交步骤

### 当前推荐：创建自己的Tap

1. **创建GitHub仓库**：
   ```bash
   # 仓库名必须是: homebrew-<name>
   # 例如: homebrew-swiftcapture
   ```

2. **用户安装方式**：
   ```bash
   brew tap GlennWong/swiftcapture
   brew install swiftcapture
   ```

### 未来：提交到Homebrew Core

当项目更成熟时：

1. **Fork Homebrew Core**：
   ```bash
   git clone https://github.com/Homebrew/homebrew-core.git
   cd homebrew-core
   ```

2. **添加Formula**：
   ```bash
   cp path/to/swiftcapture.rb Formula/
   ```

3. **测试Formula**：
   ```bash
   brew install --build-from-source Formula/swiftcapture.rb
   brew test swiftcapture
   brew audit --strict swiftcapture
   ```

4. **提交PR**：
   - 创建分支
   - 提交Formula
   - 创建Pull Request到homebrew-core

## 当前行动计划

1. ✅ 完善项目文档
2. ✅ 添加更多测试
3. ✅ 设置GitHub Actions CI
4. 🔄 推广项目获得更多用户
5. 🔄 收集用户反馈
6. 🔄 当达到要求时提交到Homebrew Core