# SiriRemoteTouchMouse

这个小工具只做一件事：监听 Apple TV 遥控器中间触摸面的滑动，并模拟鼠标移动。

实体上、下、左、右按键继续交给 Karabiner 处理；这个工具不会改 Karabiner 配置，所以不会和现有按键绑定抢功能。

## 重要说明

默认运行的是开关模式：

- 双击确认键：开启/关闭中间触摸面鼠标滑动。
- 开启后：中间触摸面滑动会移动鼠标。
- 关闭后：中间触摸面不会影响鼠标。

这样做是为了避免 Mac 自带触控板或普通鼠标也被误当成遥控器滑动。

## 当前按键规则

- 双击返回键：切换到左边桌面，相当于 `control + left_arrow`。
- 双击 Home 键：切换到右边桌面，相当于 `control + right_arrow`。
- 单击确认键：回车。
- 双击确认键：开启/关闭中间触摸面鼠标滑动。
- 静音键单击：删除。
- 静音键长按：全选并清空当前输入框。
- 上、下、左、右实体键：键盘方向键。

## 快速修改触摸滑动开关键

如果想把“开启/关闭中间触摸面滑动”的按键换掉，只改这个文件：

`remote-settings.json`

里面的 `touchMouseToggleButton` 可以填：

- `selection`：确认键
- `back`：返回键
- `home`：Home 键
- `mute`：静音键
- `play_pause`：播放/暂停键
- `microphone`：麦克风键

改完后运行：

`node tools/configure-touch-toggle.mjs`

这一步会重新生成 `karabiner-siri-remote-safe.json`。如果要立刻应用到 Karabiner，再把生成后的配置复制到：

`/Users/jin/.config/karabiner/karabiner.json`

## 怎么运行

如果你想让 AI 或自己一键安装，优先用这个脚本：

`node tools/install-touch-mouse-app.mjs`

它会自动完成：生成 Karabiner 配置、自测、编译、打包、备份旧配置、安装到 `/Applications`、重启 App、验证 Karabiner 配置。

如果只是想先看它会做什么，不真正改系统，运行：

`node tools/install-touch-mouse-app.mjs --dry-run`

1. 进入目录：
   `cd touch-mouse-app`

2. 编译和自测：
   `make test`

3. 启动监听：
   `make run`

如果你只想测试最安全的设备级直连模式，不想启动 Karabiner 备用模式，可以运行：

`./build/SiriRemoteTouchMouse --no-fallback`

如果要恢复旧的备用模式，可以运行：

`./build/SiriRemoteTouchMouse --unsafe-karabiner-fallback`

注意：旧备用模式会读取所有多点触控变量，可能影响 Mac 正常触控板，不建议日常使用。

如果首次运行时不能移动鼠标，请打开：

`系统设置 -> 隐私与安全性 -> 辅助功能`

然后给运行这个程序的终端或 Codex 开启权限。权限就像“允许这个程序帮你移动鼠标”的开关。

如果日志里出现：

`[arm] HID 监听打开失败`

意思是 macOS 暂时不允许这个程序读取遥控器的原始输入。当前版本还会走 Karabiner 备用路线，所以不影响使用。

## 现在的验证标准

- 运行后能看到 `remote-touch` 设备。
- 双击确认键后，日志出现 `[mode] touch mouse enabled` 或 `[mode] touch mouse disabled`。
- 开启模式后，手指在遥控器中间触摸面滑动时，日志出现 `[fallback] ... dx=... dy=...`。
- 鼠标指针跟随滑动方向移动。
