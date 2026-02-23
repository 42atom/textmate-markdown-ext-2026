# textmate-markdown-ext-2026

[English](README.md) | [中文](README.zh-CN.md)

为 TextMate Markdown 预览做的一组增强：

- Typora 官方 `github.css` 主题注入（尽量接近 Typora 观感）
- 预装了 [95id 文章](https://blog.95id.com/five-css-of-markdown.html) 相关的 5 套样式（原文“豆瓣样式”缺少下载源，使用 `blueTex` 替代）：
  - `techo`
  - `han`
  - `lixiaolai`
  - `vue`
  - `bluetex`
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

可选主题切换：

- 在 `~/.tm_properties` 或项目 `.tm_properties` 中设置：
  - `TM_MARKDOWN_THEME = han`
- 支持值：`github`、`techo`、`han`、`vue`、`bluetex`、`lixiaolai`


## 字体依赖（主要针对 `bluetex`）

`bluetex` 上游 CSS 引用了以下字体：

- `PingFang SC`：macOS 系统内置字体（一般无需额外安装）
- `Cascadia Code`： [microsoft/cascadia-code releases](https://github.com/microsoft/cascadia-code/releases)
- `Maple Mono NF CN`： [subframe7536/maple-font releases](https://github.com/subframe7536/maple-font/releases)  
  建议下载包含 `MapleMono-NF-CN` 关键字的压缩包

即使不安装这些字体，预览功能仍可用，只是视觉效果会与 `bluetex` 原设计有差异。

## 关键设计说明


### 旧报错的根因说明

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
