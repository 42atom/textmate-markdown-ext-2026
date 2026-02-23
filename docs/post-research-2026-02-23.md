# TextMate Markdown 双窗预览联动 Post 研究（2026-02-23）

## 结论（先行）

在 **TextMate 内部（原生预览窗口）**，目前没有发现比“手动触发 + 必要时重开预览窗”更稳定、且无闪动的方案。  
原因不是脚本技巧不足，而是 TextMate 对预览窗口的可编程控制接口存在天然缺口。

补充：历史报错的根因也不是单一“Ruby 版本太旧”，而是旧 Bundle 运行时链路整体老化（旧 shebang/参数 + 旧渲染依赖）。

## 研究目标

1. 是否存在官方接口可以直接控制“已打开的预览窗口滚动位置”。
2. 是否存在事件机制可在“光标/选择变化”时自动刷新并同步滚动。
3. 是否有更优雅替代方案（至少不闪窗）。

## 研究结论

### 1) 没有可直接控制预览滚动位置的官方外部接口

- TextMate AppleScript 暴露能力非常有限，`TextMate suite` 仅见 `get url`，没有“执行某个 Bundle 命令并返回预览句柄/滚动 API”的能力。
- 预览本质是 HTML 输出窗口，命令可以注入 JS 改滚动，但这是页面内脚本行为，不是“编辑器外部 API”。

结论：可以在渲染时“尝试滚动”，但难以可靠控制“已存在预览窗口的状态机”。

### 2) 自动联动事件不覆盖“光标移动”

- TextMate 帮助文档 `events.html` 写明可用事件非常少（历史文档里仅提到 `event.document.did_save`）。
- 当前 Markdown 预览命令配置中，`autoRefresh` 为 `DocumentChanged`，不是 Selection/Caret 级事件。

结论：不改文档内容时，天然缺少“自动刷新并重算滚动”的触发来源。

### 3) 为什么“无闪动方案”不稳定

我们实测过“只触发 Show Preview，不重开窗口”的路线：

- 分屏命令每次都执行到了；
- 但预览命令并非每次都重新进入渲染流程（日志证据：多次触发只记录到一次 ratio）；
- 于是出现“到底成功，回顶失败”的不对称行为。

结论：仅依赖复用旧预览窗时，刷新链路存在非确定性。

### 4) 是否有更优雅替代

- **TextMate 内部**：未找到更优雅且稳定的官方方案。
- **TextMate 外部**：Marked 2 官方文档声明支持 TextMate，并支持“跟踪源文档位置”（可做到更平滑的联动体验），但这是外部预览器方案，不是 TextMate 内置预览窗。

## 当前落地方案（已采用）

- 保持 A 窗口位置和宽度不变；
- B 窗口与 A 同宽，放右侧；
- 每次触发先关闭旧预览窗，再调用 `Show Preview`，确保滚动计算重新执行；
- 代价：会有轻微“闪窗”。

## 决策

- 决策：保留当前方案（稳定优先）。
- 不做：继续深挖“无闪、纯内置、100%稳定”的 TextMate 内部方案（当前证据不足以支撑）。
- 可选升级：若后续需要更顺滑体验，迁移到 Marked 2 作为外部预览器。

## Evidence（可复现证据）

### Docs

1. TextMate HTML Output / JavaScript API（官方）  
   [Building an HTML Output Command](https://macromates.com/blog/2013/building-an-html-output-command/)
2. TextMate Commands Manual（官方）  
   [Working With Commands](https://manual.macromates.com/en/working_with_commands)
3. Marked 2 与 TextMate 集成（官方）  
   [Marked 2 官网](https://marked2app.com/)
4. Marked 2：跟踪源文档位置（官方）  
   [Tracking Source Location Precisely](https://marked2app.com/docs/TRACKING_PRECISE.html)

### Code

1. `/Users/admin/Library/Application Support/TextMate/Bundles/Markdown.tmbundle/Commands/Split Windows.tmCommand`  
   现行稳定脚本（重开预览 + 双窗定位）。
2. `/Users/admin/Library/Application Support/TextMate/Managed/Bundles/Markdown.tmbundle/Commands/Markdown preview.plist`  
   `autoRefresh = ["DocumentChanged"]`。
3. `/Users/admin/Library/Application Support/TextMate/Managed/Bundles/Bundle Support.tmbundle/Support/shared/lib/tm/htmloutput.rb`  
   预览页模板与脚本注入入口（HTML 输出机制）。
4. `/Applications/TextMate.app/Contents/Resources/TextMate Help/events.html`  
   事件机制说明（历史文档中事件极少）。

### Tests

1. 手测路径 A：A 光标到底部 -> `⌥⌘S` -> B 到底（通过）。
2. 手测路径 B：A 光标回顶部 -> `⌥⌘S` -> B 回顶（在“重开预览”方案下通过）。

### Logs

1. `/tmp/tm_split_debug.log`（调试阶段）  
   显示分屏脚本多次执行成功。
2. `/tmp/tm_preview_scroll_debug.log`（调试阶段）  
   在非重开方案下出现“多次触发但仅一次 ratio 记录”的证据。

---

（章节级）评审意见：[留空,用户将给出反馈]
