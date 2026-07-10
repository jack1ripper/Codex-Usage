# Codex-Usage 产品设计文档

- **日期**：2026-07-10
- **状态**：已评审，待实现
- **目标平台**：macOS 14+
- **产品形态**：桌面悬浮球

---

## 1. 产品定位

Codex-Usage 是一个仅面向 macOS 的轻量工具型应用。它把 OpenAI Codex 的「5 小时用量剩余」和「本周用量剩余」从网页菜单中解放出来，以一个可拖动的桌面悬浮球形式常驻显示，让用户无需打开浏览器即可一眼掌握用量状态。

核心原则：
- **最小化**：只展示最关键的两项用量 + 重置倒计时。
- **零配置**：依赖用户已经安装并登录的 Codex CLI，不需要 API Key、不需要浏览器 Cookie。
- **直观**：悬浮球始终置顶，信息直接可见。

---

## 2. 功能范围

### 2.1 MVP 功能
- 悬浮球始终置顶显示在所有窗口之上。
- 悬浮球可自由拖动，并记住退出时的位置。
- 展示 **5 小时用量剩余**（primary window）。
- 展示 **本周用量剩余**（secondary window）。
- 展示两个窗口各自的 **重置倒计时**。
- 自动刷新（默认每 60 秒）。
- 右键菜单：手动刷新 / 打开设置 / 退出应用。

### 2.2 明确不做
- 不支持 Codex 以外的其他 AI provider。
- 不做历史用量图表、成本统计。
- 不做登录/授权流程，依赖 Codex CLI 已登录状态。
- 不做低用量通知/提醒（保持极简）。
- 不做菜单栏模式（悬浮球是唯一入口）。

---

## 3. 数据源与数据流

### 3.1 数据来源
采用 **Codex CLI RPC** 作为唯一数据源：

```bash
codex -s read-only -a untrusted app-server
```

通过子进程 stdin/stdout 进行 JSON-RPC 通信：

```json
{
  "jsonrpc": "2.0",
  "method": "account/rateLimits/read",
  "id": 1
}
```

### 3.2 返回关键字段
```json
{
  "rate_limits": {
    "primary": {
      "used_percent": 45.0,
      "window_duration_mins": 300,
      "resets_at": 1752158400
    },
    "secondary": {
      "used_percent": 30.0,
      "window_duration_mins": 10080,
      "resets_at": 1752441600
    }
  }
}
```

- `used_percent`：已用量百分比（0–100）。
- `window_duration_mins`：窗口总时长（分钟），可选。
- `resets_at`：重置时间的 Unix 时间戳（秒）。

### 3.3 刷新策略
- 应用启动时立即刷新一次。
- 之后每 60 秒自动刷新。
- 右键菜单支持手动刷新。
- 同一时刻最多只启动一个 `codex app-server` 进程。

---

## 4. UI/UX 设计

### 4.1 悬浮球外观
尺寸约 **140×140 pt** 的圆形悬浮球：

```
        ╭─────────────╮
       ╱   5h   Weekly ╲
      │   ╭───────╮     │
      │  ╱    74%   ╲    │  ← 中心显示最近窗口剩余百分比
      │ │   2h 14m  │   │  ← 最近重置窗口倒计时
      │  ╲  until reset ╱   │
      │   ╰───────╯     │
       ╲    Codex     ╱
        ╰─────────────╯
```

### 4.2 展示规则
- **外环**：5 小时用量剩余。
- **内环**：本周用量剩余。
- **中心大字**：最近即将重置窗口的剩余时间（如 `2h 14m`）。
- **小字标签**：`5h` / `Weekly`。
- **背景**：深色半透明 + 毛玻璃效果。
- **颜色状态**：
  - 剩余 > 30%：蓝色/绿色。
  - 剩余 10%–30%：黄色。
  - 剩余 < 10%：红色。

### 4.3 交互
- **左键拖动**：按住悬浮球任意位置即可拖动。
- **右键点击**：弹出菜单（刷新 / 设置 / 退出）。
- **无左键点击展开详情**：保持极简。

---

## 5. 技术架构

### 5.1 技术栈
| 层级 | 技术 |
|------|------|
| UI | SwiftUI |
| 窗口管理 | AppKit `NSPanel`（`level: .floating`，`collectionBehavior: .canJoinAllSpaces`） |
| 数据获取 | `Process` 启动 `codex app-server`，JSON-RPC over stdin/stdout |
| 定时刷新 | `Timer` + Combine |
| 持久化 | `UserDefaults`（窗口位置、刷新间隔） |
| 构建打包 | Xcode Archive → `.app` |

### 5.2 核心模块
- `CodexRPCClient`：管理 `codex app-server` 子进程生命周期，发送/接收 JSON-RPC。
- `UsageModel`：用量数据结构，包含 primary/secondary window 的 used、total、resetsAt。
- `FloatingBallView`：SwiftUI 悬浮球视图。
- `FloatingWindowController`：管理窗口无边框、置顶、拖动、位置记忆。
- `UsageRefreshService`：定时刷新、状态聚合、错误降级。

### 5.3 项目结构
```
Codex-Usage/
├── Codex-Usage.xcodeproj
├── Codex-Usage/
│   ├── App/
│   │   ├── Codex_UsageApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   └── FloatingBallView.swift
│   ├── Windows/
│   │   └── FloatingWindowController.swift
│   ├── Services/
│   │   ├── CodexRPCClient.swift
│   │   └── UsageRefreshService.swift
│   ├── Models/
│   │   └── UsageModel.swift
│   └── Resources/
│       └── Assets.xcassets
├── README.md
└── .gitignore
```

---

## 6. 错误处理

| 场景 | 处理 |
|------|------|
| Codex CLI 未安装 | 悬浮球变灰，中心显示 `Install Codex`，右键提供跳转到安装文档。 |
| Codex 未登录 | 显示 `Run codex login`。 |
| RPC 调用失败/超时 | 保留上次成功数据，进度环变灰/虚线，显示 `Offline`。 |
| 用量字段缺失 | 对应位置显示 `—`。 |
| 窗口位置越界 | 启动时校验屏幕边界，自动拉回可见区域。 |

---

## 7. 后续可扩展（不在 MVP）

- 接入 OAuth API 作为 CLI RPC 的备选数据源。
- 增加菜单栏图标 + 菜单栏模式。
- 低用量时发送系统通知。
- 支持多 Codex 账户切换。
- 历史用量趋势小图。

---

## 8. 验收标准

- [ ] 悬浮球可在桌面任意位置拖动并记住位置。
- [ ] 启动后 5 秒内显示最新 5 小时/本周用量。
- [ ] 5 小时和本周用量用两个进度环同时展示。
- [ ] 重置倒计时直接显示在球上。
- [ ] 右键菜单包含刷新、设置、退出。
- [ ] Codex CLI 未安装或未登录时给出明确提示。
- [ ] 应用在 macOS 14+ 上正常运行。
