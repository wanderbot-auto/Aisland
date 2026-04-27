# Settings Design Outline

本轮设置页设计稿基于当前 Figma 会话中的深色玻璃化样式继续扩展，目标是把 `SettingsView` 中已经存在的功能页全部整理成可评审的完整设计组。

## Figma 交付范围

- 当前 Figma 文件新增页面：`Settings Screens`
- 已完成的画板：
  - `Settings · General`
  - `Settings · Setup`
  - `Settings · AI Chat`
  - `Settings · Skills`
  - `Settings · White Noise`
  - `Settings · Display`
  - `Settings · Usage`
  - `Settings · Sound`
  - `Settings · Appearance`
  - `Settings · Shortcuts`

## 设计原则

- 延续现有 Figma 稿的深色磨砂面板、低饱和描边、荧光强调色和 macOS utility window 结构。
- 每个页面统一保留相同的视觉系统：深色磨砂容器、细描边、荧光强调、macOS utility window 节奏。
- 左侧导航改为固定信息架构，不再为了强调当前页而打乱顺序；分区基于真实功能：
  - `App Settings`：General / Appearance / Shortcuts
  - `Agent Tasks`：Setup / Display / Usage
  - `AI Chat`：AI Chat / Skills
  - `White Noise`：White Noise / Sound
- 右侧内容区不再强制套用 `General` 页的统一骨架，而是按照实际配置项数量与操作密度决定是 2 段、3 段还是 4 段式布局。
- 内容映射以 `Sources/AislandApp/Views/SettingsView.swift` 与 `Sources/AislandApp/Views/AppearanceSettingsPane.swift` 的真实功能为准，不新增超出当前产品边界的设置项。

## 页面映射

### General

- 语言与本地化
- 行为开关
- 通知偏好
- 应用存在感与 Dock 呈现

### Setup

- Claude / Codex / OpenCode 安装入口
- 健康检查与修复
- 权限说明
- Usage bridge

### AI Chat

- Provider 搜索与选择状态
- Model override / Keychain 凭据状态
- Provider 卡片使用弱色彩处理，避免多服务商高饱和色抢占视觉层级

### Skills

- Skills 能力说明
- 导入入口
- 已安装列表
- 来源、覆盖与卸载动作

### White Noise

- 声景库
- 混音状态
- 分类预设
- 播放控制

### Display

- 目标显示器选择
- 当前定位诊断
- Island token usage 展示方式
- Header/placement 预览语义

### Usage

- 刷新与最近更新时间
- 今日岛上展示配置
- 关键汇总指标（Total / Input / Output / Entries）
- Day / Month / Session 紧凑列表
- 使用中性色与弱描边，避免 provider 与指标颜色抢占视觉层级

### Sound

- 通知静音
- 声音列表
- 试听动作
- 当前选中状态

### Appearance

- 默认 / 自定义模式
- Island 预览
- 高级自定义
- 状态色

### Shortcuts

- Global shortcuts
- 录制态
- Tab 导航
- 恢复默认

## 当前说明

- 已移除左下角会员卡片以及 `Behavior defaults` 按钮，避免出现当前产品里并不存在的会员 / 默认模板心智。
- 当前静态稿侧重评审信息架构与布局差异：`General`、`Skills`、`Sound`、`Shortcuts` 等低配置密度页面已收敛成 2 段式；`Display` 保留 3 段；`AI Chat`、`Setup`、`Appearance` 继续承载更高的信息量。
- `Settings · AI Chat` 已按当前 `SettingsView.swift` 的真实实现语义调整为 provider-first：主体区围绕 provider 搜索、默认模型/override、API key 存储组织，不再单独展示推荐模型与快捷键设置区。
- `Settings · Usage` 已收敛为紧凑统计配置页：隐藏低价值数据源明细，减少汇总卡片数量，并统一使用弱色彩、弱描边与更小行高。
- 后续如进入实现阶段，再逐页细化控件状态、空态、错误态和滚动细节。
