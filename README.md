# Siri Remote Karabiner Setup Skill

这是一个 Codex skill，用来把 Apple TV Siri Remote 变成 macOS 遥控器。

它包含两部分：

- Karabiner-Elements 按键映射：把遥控器实体按键映射成方向键、Enter、鼠标左右键、桌面切换、删除等动作。
- 触摸滑动 App：监听遥控器中间触摸面，让触摸滑动模拟鼠标移动。

## 映射图

![Apple TV Siri Remote macOS mapping](assets/siri-remote-white-vibe-coding-map.png)

## 主要功能

- 上、下、左、右实体键映射为键盘方向键。
- 单击确认键映射为 `Enter`。
- 双击确认键开启/关闭触摸面鼠标滑动。
- 返回键单击映射为鼠标左键 + `Enter`，双击映射为 `Control + ←`。
- Home 键单击映射为鼠标右键，双击映射为 `Control + →`。
- 静音键单击删除，长按全选并清空。
- 音量键映射为上下滚动。
- 侧边麦克风键映射为 `Fn`。

## 一键安装

在仓库根目录运行：

```bash
node touch-mouse-app/tools/install-touch-mouse-app.mjs
```

首次安装前建议先预演：

```bash
node touch-mouse-app/tools/install-touch-mouse-app.mjs --dry-run
```

安装后，macOS 仍然需要手动开启辅助功能、输入监控等系统权限。

## 修改触摸滑动开关键

编辑：

```text
touch-mouse-app/remote-settings.json
```

然后重新生成 Karabiner 配置：

```bash
node touch-mouse-app/tools/configure-touch-toggle.mjs
```

## 目录说明

- `SKILL.md`：Codex skill 主说明。
- `assets/`：映射图和 Karabiner 导入配置。
- `references/`：安装、事件映射、排错说明。
- `scripts/`：Karabiner 配置安装脚本和映射图生成脚本。
- `touch-mouse-app/`：触摸面鼠标移动 App 源码和一键安装脚本。
