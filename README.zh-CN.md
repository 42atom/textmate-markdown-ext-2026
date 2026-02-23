# textmate-markdown-ext-2026

[English](README.md) | [中文](README.zh-CN.md)

为 TextMate Markdown 预览做的一组增强：

- Typora 官方 `github.css` 主题注入（尽量接近 Typora 观感）
- Mermaid 代码块真渲染（` ```mermaid `）
- MathJax 注入
- 修复 `ruby18 -wKU` 触发的 `-K` 警告尾巴
- 新增 `Preview Side by Side` 命令（`Option + Command + S`）
- A/B 双窗布局：A 保持原位置和宽度，B 在右侧同宽显示预览
- 预览滚动定位：按 A 光标行号比例定位 B 预览

## 兼容性

- macOS（当前仓库验证环境：`macOS 26.3`，`build 25D125`）
- TextMate Bundles 路径：
  - `~/Library/Application Support/TextMate/Managed/Bundles`
  - `~/Library/Application Support/TextMate/Bundles`

## 安装

```bash
cd /Users/admin/GitProjects/textmate-markdown-ext-2026
./scripts/install.sh
```

安装后：

1. 重启 TextMate，或执行 `Bundles -> Bundle Editor -> Reload Bundles`
2. 打开 Markdown 文件
3. 使用 `Option + Command + S` 进行左右分窗预览

## 关键设计说明

### 为什么分屏命令会“闪窗”

当前稳定方案采用“先关闭旧预览窗，再重新打开预览窗”，原因是 TextMate 内置预览在某些场景不会稳定重跑渲染链。重开能保证滚动定位每次生效，但会带来轻微闪窗。

详细研究见：`docs/post-research-2026-02-23.md`

### 旧报错的根因说明

你看到的旧报错并不只是“Ruby 太旧”一个原因，而是“老旧 Bundle 运行链兼容性”问题：

- `ruby20: No such file or directory`、`-K is specified`：主要来自旧 shebang/参数（如 `ruby18 -wKU`）与现代 macOS Ruby 环境不匹配。
- `no lexer for alias 'mermaid' found`：是渲染链里 Pygments 词法器映射问题，不是单纯 Ruby 版本问题。

所以更准确的结论是：**根因是历史 Bundle 运行时链路老化**，Ruby 版本问题是其中一个核心子项。

## 文件结构

- `scripts/install.sh`：一键安装脚本
- `templates/redcarpet.rb`：Markdown (GitHub) 渲染器模板
- `templates/append_mathjax_js.rb`：MathJax + Mermaid 注入模板
- `templates/show_preview.rb`：Show Preview 命令模板（含滚动定位）
- `templates/Split Windows.tmCommand`：分屏命令（`⌥⌘S`）
- `docs/post-research-2026-02-23.md`：方案研究记录

## 权限提示

分屏命令使用 `System Events` 点击 TextMate 菜单，首次可能需要在 macOS 中授权辅助功能：

- 系统设置 -> 隐私与安全性 -> 辅助功能
- 允许 TextMate（以及你用于触发命令的终端/工具）

## License

MIT
