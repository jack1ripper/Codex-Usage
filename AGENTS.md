# Codex-Usage Agent Guide

> 本文件面向后续接手或协助本项目的 AI Agent / 开发者，记录项目背景、构建、验证与发布流程。
>
> This guide is for future AI agents / developers working on this project. It covers background, build, verification, and release workflows.

## 项目概述 / Project Overview

Codex-Usage 是一款极简的 macOS 菜单栏应用，用于展示 OpenAI Codex CLI 的使用量（5 小时限额 / 每周限额）。

Codex-Usage is a minimalist macOS menu bar app that displays OpenAI Codex CLI usage (5-hour limit / weekly limit).

- 本地路径 / Local path: `/Users/dengxiang/Codex-Usage`
- GitHub 仓库 / GitHub repo: `jack1ripper/CodeX-Usage`
- Homebrew Tap: `jack1ripper/homebrew-tap`
- Cask 名称 / Cask name: `codex-usage`
- Bundle ID: `com.codexusage.Codex-Usage`
- 目标平台 / Target platform: macOS 14 (Sonoma) +

## 技术栈 / Tech Stack

- Swift 6.0
- Swift Package Manager (`Package.swift`)
- AppKit / Foundation（非 SwiftUI）
- Codex CLI JSON-RPC (`codex -s read-only -a untrusted app-server --stdio`)

## 构建与运行 / Build & Run

```bash
cd /Users/dengxiang/Codex-Usage
swift build
swift test
./Scripts/build_app.sh
./Scripts/install.sh
```

`build_app.sh` 会在项目根目录生成 `Codex-Usage.app`；`install.sh` 会把它复制到 `/Applications`。

`build_app.sh` creates `Codex-Usage.app` in the project root. `install.sh` copies it to `/Applications`.

## 开发验证流程 / Development Verification

每次完成代码修改后，必须完成以下步骤才算验证通过：

After every code change, complete the following verification before declaring done:

1. **构建并测试 / Build & Test**
   ```bash
   swift build
   swift test
   ./Scripts/build_app.sh
   ```

2. **退出已运行的旧版本 / Quit the running old version**
   ```bash
   osascript -e 'quit app "Codex-Usage"'
   ```
   或直接右键菜单栏图标选择 Quit。
   Or right-click the menu bar icon and select Quit.

3. **重新安装并启动 / Re-install and launch**
   ```bash
   ./Scripts/install.sh
   open /Applications/Codex-Usage.app
   ```

> 如果只是验证构建是否通过，可以只执行第 1 步；但如果要确认 UI/交互/资源改动生效，必须执行第 2、3 步。
> Step 1 alone is enough to verify compilation. Steps 2 and 3 are required to confirm UI/interaction/resource changes take effect.

## 资源文件修改 / Resource Changes

当修改以下资源时，macOS 可能会缓存旧资源，仅覆盖 `/Applications/Codex-Usage.app` 可能无法生效：

When modifying the resources below, macOS may cache the old versions. Simply overwriting `/Applications/Codex-Usage.app` may not work:

- `Sources/Codex-Usage/Resources/AppIcon.icns`
- `Sources/Codex-Usage/Resources/CodexUsageLogo.png`
- 任何 `Resources` 目录内的图片或图标文件

**处理方式 / Handling:**

```bash
osascript -e 'quit app "Codex-Usage"'
rm -rf /Applications/Codex-Usage.app
./Scripts/build_app.sh
./Scripts/install.sh
open /Applications/Codex-Usage.app
```

即：**先彻底删除应用，再重新构建安装**。

In short: **delete the app completely, then rebuild and reinstall**.

## 发布新版本 / Releasing a New Version

当用户要求"发布新版本"时，必须同时完成以下两件事：

When the user asks to "release a new version", you must do **both** of the following:

### 1. 更新应用版本并推送 Release / Bump app version and push a release

1. 统一更新以下文件中的版本号（例如从 `0.1.1` 到 `0.1.2`）：
   - `Codex-Usage.app/Contents/Info.plist`
   - `Scripts/build_app.sh`
2. 提交并推送标签：
   ```bash
   cd /Users/dengxiang/Codex-Usage
   git add .
   git commit -m "Release v0.1.2"
   git tag v0.1.2
   git push origin main v0.1.2
   ```
3. GitHub Actions (`.github/workflows/release.yml`) 会自动构建并上传 `Codex-Usage.app.zip` 到 GitHub Release。

### 2. 同步更新 Homebrew Cask / Sync the Homebrew cask

Cask 文件位置：

```
/Users/dengxiang/homebrew-tap/Casks/codex-usage.rb
```

需要更新：

```ruby
version "0.1.2"
```

如果 release 中的 zip 使用了固定 `sha256`，还需要更新 sha256；当前为 `sha256 :no_check`，可以暂不修改。但如果未来改用固定校验，必须同步更新。

If the release zip uses a pinned `sha256`, update it too. Currently `sha256 :no_check` is used, so no sha change is required unless you switch to pinned hashes.

然后推送 tap 仓库：

```bash
cd /Users/dengxiang/homebrew-tap
git add Casks/codex-usage.rb
git commit -m "Bump codex-usage to 0.1.2"
git push origin main
```

### 3. 告知用户 / Inform the user

发布完成后，告诉用户：

```
新版本 v0.1.2 已发布。
GitHub Release: https://github.com/jack1ripper/CodeX-Usage/releases/tag/v0.1.2
Homebrew 用户可运行：
  brew update
  brew upgrade --cask codex-usage
```

## Homebrew 安装 / Homebrew Install

其他用户通过以下命令安装：

```bash
brew tap jack1ripper/tap
brew install --cask codex-usage
```

## 文档规范 / Documentation Conventions

- `README.md` 保持中英双语、上下对应格式：每段中文在前，英文紧随其后。
- 所有面向用户的安装/构建命令必须同时出现在 README 中。
- 修改 README 后，同步检查英文翻译是否保持一致。

## 常见命令速查 / Quick Reference

```bash
# 构建
swift build

# 测试
swift test

# 构建 app bundle
./Scripts/build_app.sh

# 安装到 /Applications
./Scripts/install.sh

# 退出已运行实例
osascript -e 'quit app "Codex-Usage"'

# 彻底删除并重装（资源改动后）
rm -rf /Applications/Codex-Usage.app
./Scripts/build_app.sh
./Scripts/install.sh
open /Applications/Codex-Usage.app
```
