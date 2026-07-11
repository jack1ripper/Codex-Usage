# Codex-Usage 设置、悬浮刷新与协议兼容设计

**日期：** 2026-07-11  
**状态：** 待用户确认

## 目标

完成三项相互关联的体验与可靠性改进：

1. 设置页采用 macOS 标准的即时保存行为，删除误导性的“保存设置”按钮。
2. 修复 Codex CLI 路径输入框被 `Form` 挤压、示例路径被当成标签的问题，并提供即时路径状态。
3. 将悬浮窗左侧 Logo 栏改成有明确反馈的刷新入口，同时增强 Codex App Server 响应兼容和安全降级。

## 方案比较

### 设置页

- **方案 A：保留保存按钮，改成真正的草稿提交。** 需要为全部设置增加临时状态、取消和回滚，复杂度高，也不符合轻量 macOS 设置页的使用预期。
- **方案 B：即时保存并删除保存按钮（采用）。** 保留现有 `@AppStorage` 数据流，关闭窗口只负责关闭，不暗示有未提交修改。

### 悬浮窗左侧栏

- **方案 A：完全删除 Logo。** 最简洁，但失去数据来源识别、过期状态和可见刷新入口。
- **方案 B：把 Logo 栏变为状态/刷新栏（采用）。** 默认显示品牌 Logo，悬停显示刷新图标，刷新中显示进度，过期时保留橙色状态点。
- **方案 C：点击整个悬浮窗刷新。** 与窗口拖动冲突，且容易误触，不采用。

### Codex App Server 兼容

- **方案 A：严格绑定当前 schema。** 简单，但旧版字段和未来多 bucket 响应容易中断。
- **方案 B：运行时调用 schema 生成器。** 生成器仍标记为 experimental，增加启动成本和失败面，不适合终端用户应用。
- **方案 C：宽容解码、严格语义校验（采用）。** 同时接受历史 snake_case、当前 camelCase 和多 bucket 响应；只忽略非关键新增字段，关键额度窗口缺失时明确失败，绝不默认成 0% 已用。

## 详细设计

### 1. 设置页即时保存

- 删除 `SettingsView.onSave`、底部“保存设置”Section 和 `applySettings()`。
- 继续使用 `@AppStorage`；刷新间隔在 Binding setter 中限制到 60–3600 秒。
- `UsageRefreshService` 继续监听 `UserDefaults.didChangeNotification` 并立即重建计时器。
- 设置窗口关闭按钮只隐藏窗口；再次打开时直接反映已保存值。
- 设置窗口内容宽度调整到 440pt，保留当前分组式视觉语言。

### 2. Codex CLI 路径控件

- 使用真正的 `prompt` 显示 `/usr/local/bin/codex`，不再把它作为 `TextField` 标签。
- 输入框隐藏 Form 的额外标签并优先获得横向空间；“浏览…”按钮保持固定尺寸。
- 路径为空：显示自动检测结果；未检测到时显示中性提示。
- 路径非空且有效：显示“路径有效”。
- 路径非空但无效、不是可执行文件、不是名为 `codex` 的文件：显示明确错误。
- 浏览文件后继续即时写入 `@AppStorage`。

### 3. 悬浮窗刷新入口

- 左侧栏使用一个 plain button，而不是纯装饰视图。
- 默认：显示 Codex Logo。
- 悬停：显示 `arrow.clockwise` 和“刷新用量”帮助提示。
- 刷新中：显示小型 `ProgressView`，禁用重复刷新。
- 过期：显示橙色状态点；点击仍可重试。
- 控件提供“刷新 Codex 用量”辅助功能名称；刷新中改为“正在刷新 Codex 用量”。
- 左侧栏吃掉点击，悬浮窗其余区域继续承担拖动。

### 4. App Server 响应兼容

本机 Codex CLI 0.144.0-alpha.4 生成的 v2 schema 将 `rateLimits` 定义为向后兼容单 bucket，并提供可选的 `rateLimitsByLimitId` 多 bucket 视图。实现遵循以下选择顺序：

1. 使用同时包含 primary 和 secondary 的 `rateLimits`。
2. 若单 bucket 不完整，优先使用 `rateLimitsByLimitId["codex"]`。
3. 若没有 `codex` 键，使用第一个同时包含 primary 和 secondary 的 bucket。
4. 仍找不到完整窗口时，抛出专用兼容错误，不构造假的 100% 剩余额度。

解码要求：

- `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`，兼容 snake_case 与 camelCase。
- `usedPercent` 使用 `Double`，同时接受 JSON 整数和小数。
- 未识别的新增字段由 `Codable` 默认忽略。
- JSON-RPC `error`、未登录、超时和 CLI 不存在继续沿用现有错误路径。
- 初始化请求维持最小 `clientInfo`，不主动加入实验能力，避免破坏旧版本。

### 5. 错误体验

- 新增明确的“Codex CLI 返回了不兼容的用量数据”错误类型。
- 有旧快照时继续显示旧数据并标记过期。
- 无旧快照时，弹窗和悬浮窗显示兼容错误，不显示伪造额度。
- 设置页路径错误不阻止关闭，但会持续显示即时错误状态。

## 测试策略

先写失败测试，再实现：

- 历史 snake_case 单 bucket 响应。
- 当前 camelCase 单 bucket 响应。
- `rateLimitsByLimitId.codex` 回退。
- 任意完整 bucket 回退。
- primary 或 secondary 缺失时抛兼容错误。
- 未知新增字段不影响解析。
- 路径为空、有效、无效、目录和错误文件名的状态测试。
- 刷新按钮默认、悬停、加载和过期状态决策测试。
- 保留并运行全部现有测试。

## 视觉验收

实现后执行项目规定的完整流程：

1. `swift build`
2. `swift test`
3. `./Scripts/build_app.sh`
4. 退出旧应用并从 `/Applications` 删除旧 bundle。
5. 重新安装并启动。
6. 截图并检查完整设置页、路径状态、标准/紧凑切换，以及悬浮窗默认、悬停和刷新中状态。

截图必须确认没有字段换行挤压、没有保存按钮、刷新入口反馈清楚，并且悬浮窗数据仍正确显示。
