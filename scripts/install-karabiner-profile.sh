#!/bin/zsh

# 作用：
# 尽量自动完成 Siri Remote + Karabiner 的本地部署：
# 1. 检查 Karabiner 是否已安装（支持常见安装位置）
# 2. 如未安装且存在 Homebrew，则先尝试自动安装
# 3. 自动安装失败时，清楚提示用户改走手动安装
# 4. 备份当前 karabiner.json
# 5. 复制 skill 自带的双 Profile 配置
# 6. 打开 Karabiner-Elements
# 注意：macOS 权限授权与蓝牙配对仍需要用户手动确认

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
skill_dir="$(cd "$script_dir/.." && pwd)"
source_json="$skill_dir/assets/karabiner-siri-remote-on-off.json"
target_dir="$HOME/.config/karabiner"
target_json="$target_dir/karabiner.json"
timestamp="$(date +%Y%m%d-%H%M%S)"
karabiner_app=""

find_karabiner_app() {
  local candidate

  for candidate in \
    "/Applications/Karabiner-Elements.app" \
    "$HOME/Applications/Karabiner-Elements.app"
  do
    if [ -d "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

if [ ! -f "$source_json" ]; then
  echo "没有找到源配置文件：$source_json"
  exit 1
fi

if karabiner_app="$(find_karabiner_app)"; then
  echo "检测到 Karabiner-Elements：$karabiner_app"
else
  echo "没有检测到 Karabiner-Elements。"
  if command -v brew >/dev/null 2>&1; then
    echo "检测到 Homebrew，开始尝试自动安装 Karabiner-Elements..."
    echo "这一步可能会因为网络、镜像排队、Homebrew 权限或本机环境而失败。"
    echo "如果长时间卡住或安装失败，请改走手动安装。"
    if ! brew install --cask karabiner-elements; then
      echo ""
      echo "Homebrew 自动安装没有成功。"
      echo "这不代表 skill 有问题，常见原因是："
      echo "1. Homebrew 本身状态异常"
      echo "2. 下载镜像排队或网络不稳定"
      echo "3. 当前 macOS 权限不足"
      echo ""
      echo "请改用手动安装："
      echo "1. 打开 Karabiner-Elements 官网下载安装"
      echo "2. 安装完成后先手动打开一次 Karabiner-Elements"
      echo "3. 然后重新运行这个脚本"
      exit 1
    fi
  else
    echo "没有检测到 Homebrew。"
    echo "请先手动安装 Karabiner-Elements，然后重新运行这个脚本。"
    exit 1
  fi
fi

if ! karabiner_app="$(find_karabiner_app)"; then
  echo "安装流程结束后，仍然没有检测到 Karabiner-Elements。"
  echo "脚本已检查这些常见位置："
  echo "1. /Applications/Karabiner-Elements.app"
  echo "2. $HOME/Applications/Karabiner-Elements.app"
  echo "请先手动确认安装位置，再重新运行这个脚本。"
  exit 1
fi

mkdir -p "$target_dir"

if [ -f "$target_json" ]; then
  backup_json="$target_dir/karabiner.backup-$timestamp.json"
  cp "$target_json" "$backup_json"
  echo "已备份当前配置到：$backup_json"
fi

cp "$source_json" "$target_json"
echo "已写入 Karabiner 配置：$target_json"
echo "现在尝试打开 Karabiner-Elements..."
open -a "Karabiner-Elements" || true
echo "当前识别到的 Karabiner 路径：$karabiner_app"
echo "现在打开 Karabiner-Elements -> Profiles，检查是否出现："
echo "- Siri Remote On"
echo "- Siri Remote Off"
echo ""
echo "还需要人工完成的步骤："
echo "1. 在 macOS 中允许 Karabiner 的辅助功能 / 输入监控权限"
echo "2. 确认 Siri Remote 已经通过蓝牙连接到 Mac"
echo "3. 如果刚装完 Karabiner，没有生效时先退出 EventViewer 再测试"
