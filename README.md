# Codex-Usage

> 一款极简的 macOS 菜单栏工具，用于查看 OpenAI Codex 的使用量。
>
> A minimalist macOS menu bar utility for OpenAI Codex usage.

## 功能特性 / Features

- 菜单栏仅显示 Logo，点击后弹出轻量双行使用量浮窗。  
  Logo-only menu bar item that opens a light two-row usage popover.
- 同时展示 5 小时限额、每周限额、进度与重置时间。  
  Shows both the 5-hour and weekly limits, progress, and reset times at once.
- 可选置顶的双行桌面悬浮面板。  
  Optional always-on-top two-row desktop panel.
- 可拖拽桌面悬浮面板调整位置，位置会自动记忆。  
  Drag the desktop panel to reposition it; position is remembered.
- 每 5 分钟自动刷新（可在设置中调整）。  
  Auto-refreshes every 5 minutes (configurable in settings).
- 右键菜单栏 Logo 可显示/隐藏桌面面板、刷新、打开设置或退出。  
  Right-click the menu bar logo to show/hide the desktop panel, refresh, open settings, or quit.
- 支持开机自启。  
  Optional launch at login.

## 系统要求 / Requirements

- macOS 14（Sonoma）或更高版本。  
  macOS 14+.
- 已安装并完成身份验证的 Codex CLI（`codex login`）。  
  Codex CLI installed and authenticated (`codex login`).

## 一键安装 / One-Line Install

```bash
brew tap jack1ripper/tap
brew install --cask codex-usage
```

> 安装完成后，从启动台或 Spotlight 打开 `Codex-Usage` 即可。  
> After installation, launch `Codex-Usage` from Launchpad or Spotlight.

## 手动构建与安装 / Build & Install Manually

```bash
swift build
```

```bash
./Scripts/build_app.sh
./Scripts/install.sh
open /Applications/Codex-Usage.app
```

`build_app.sh` 会在项目根目录生成 `Codex-Usage.app`；`install.sh` 会将其复制到 `/Applications`，以便在启动台和 Spotlight 中显示。  
`build_app.sh` creates `Codex-Usage.app` in the project root. `install.sh` copies it to `/Applications` so it appears in Launchpad and Spotlight.

## 数据来源 / Data Source

通过本地 Codex CLI 的 JSON-RPC 接口读取数据（`codex -s read-only -a untrusted app-server --stdio`），无需 API Key 或浏览器 Cookie。  
Reads from the local Codex CLI via JSON-RPC (`codex -s read-only -a untrusted app-server --stdio`). No API keys or browser cookies required.

## 发布新版本 / Releasing a New Version

1. 更新 `Codex-Usage.app/Contents/Info.plist` 与构建脚本中的版本号。  
   Bump the version in `Codex-Usage.app/Contents/Info.plist` and the build scripts.
2. 在 `jack1ripper/CodeX-Usage` 仓库打标签并推送，GitHub Actions 会自动构建并上传 `Codex-Usage.app.zip` 到 Release。  
   Push a tag to the `jack1ripper/CodeX-Usage` repository and GitHub Actions will build and upload `Codex-Usage.app.zip` to the release.
3. 更新 `homebrew-tap/Casks/codex-usage.rb` 中的 `version` 与 `sha256`，并推送到 `jack1ripper/homebrew-tap`。  
   Update `version` and `sha256` in `homebrew-tap/Casks/codex-usage.rb`, then push to `jack1ripper/homebrew-tap`.
