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
- 每个页面统一保留：
  - 左侧导航
  - 顶部标题与单一主动作
  - 顶部 2 张摘要卡
  - 4 个内容分区标题
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
- Remote sessions 与 usage bridge

### AI Chat

- Provider 选择
- Model / Base URL / API Key
- 推荐模型
- 打开临时聊天快捷键

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

- 刷新与数据源
- 今日岛上展示
- 汇总指标
- Day / Month / Session bucket 列表

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

- 为了在静态稿里更清楚地表达“当前页已选中”，除 `General` 外，其余设置稿将当前页面放到侧栏第一项高亮展示；后续如需进入高保真阶段，可再恢复固定侧栏顺序。
- 本轮重点是把所有设置页补齐到统一视觉系统中，后续若进入实现阶段，再逐页细化控件状态、空态、错误态和滚动细节。
