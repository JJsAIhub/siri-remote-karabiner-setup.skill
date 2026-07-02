#!/usr/bin/env python3
"""生成 Apple TV 遥控器白底按键映射图。"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
BASE_IMAGE = ASSETS / "siri-remote-white-base.png"
OUT_PNG = ASSETS / "siri-remote-white-vibe-coding-map.png"
OUT_SVG = ASSETS / "siri-remote-white-vibe-coding-map.svg"

SCALE = 2
WIDTH = 1200
HEIGHT = 1600
BLUE = "#1677ff"
BLACK = "#1d1d1f"
LIGHT_GRAY = "#e7ecf3"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    """读取 macOS 中文字体；失败时回退到默认字体。"""
    candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc" if bold else "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    ]
    for item in candidates:
        path = Path(item)
        if path.exists():
            return ImageFont.truetype(str(path), size * SCALE)
    return ImageFont.load_default()


TITLE_FONT = font(54, True)
LABEL_FONT = font(25, True)
VALUE_FONT = font(25)


def s(value: int | float) -> int:
    return round(value * SCALE)


def draw_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill: str, image_font: ImageFont.ImageFont) -> None:
    draw.text((s(xy[0]), s(xy[1])), text, fill=fill, font=image_font)


def text_width(draw: ImageDraw.ImageDraw, text: str, image_font: ImageFont.ImageFont) -> int:
    box = draw.textbbox((0, 0), text, font=image_font)
    return round((box[2] - box[0]) / SCALE)


def crop_remote(base: Image.Image) -> Image.Image:
    """从白底图中裁出遥控器本体，保留一点阴影。"""
    rgb = base.convert("RGB")
    pixels = rgb.load()
    min_x, min_y = rgb.width, rgb.height
    max_x, max_y = 0, 0

    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = pixels[x, y]
            if min(r, g, b) < 246:
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    pad = 26
    return rgb.crop((
        max(0, min_x - pad),
        max(0, min_y - pad),
        min(rgb.width, max_x + pad),
        min(rgb.height, max_y + pad),
    ))


def line(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]]) -> None:
    scaled = [(s(x), s(y)) for x, y in points]
    draw.line(scaled, fill=BLUE, width=s(3), joint="curve")


def dot(draw: ImageDraw.ImageDraw, xy: tuple[int, int], radius: int = 7) -> None:
    x, y = xy
    draw.ellipse((s(x - radius), s(y - radius), s(x + radius), s(y + radius)), fill=BLUE)


def annotation(
    draw: ImageDraw.ImageDraw,
    side: str,
    x: int,
    y: int,
    title: str,
    values: list[str],
    target: tuple[int, int],
    width: int = 300,
) -> None:
    """画一组说明文字和指向遥控器的蓝色线。"""
    draw_text(draw, (x, y), title, BLACK, LABEL_FONT)
    current_y = y + 38
    for value in values:
        draw_text(draw, (x, current_y), value, BLUE, VALUE_FONT)
        current_y += 34

    line_y = y + 22
    longest_text = max([title, *values], key=lambda item: text_width(draw, item, VALUE_FONT))
    text_end = x + text_width(draw, longest_text, VALUE_FONT)
    if side == "left":
        start = (text_end + 18, line_y)
        elbow = (target[0] - 18, line_y)
    else:
        start = (x - 18, line_y)
        elbow = (target[0] + 18, line_y)
    line(draw, [start, elbow, (elbow[0], target[1]), target])
    dot(draw, target)


def draw_side_inset(draw: ImageDraw.ImageDraw) -> None:
    """画一个简化侧边视图，用来标出麦克风键。"""
    box = (820, 1310, 1120, 1548)
    draw.rounded_rectangle(tuple(s(v) for v in box), radius=s(18), outline=LIGHT_GRAY, width=s(2), fill="#ffffff")
    draw.rounded_rectangle((s(875), s(1352), s(940), s(1516)), radius=s(28), outline="#b8bec7", width=s(2), fill="#f2f4f7")
    draw.rounded_rectangle((s(902), s(1384), s(914), s(1470)), radius=s(5), fill="#1d1d1f")
    draw.rounded_rectangle((s(928), s(1384), s(946), s(1470)), radius=s(9), outline="#949aa3", width=s(2), fill="#ffffff")
    draw.rounded_rectangle((s(952), s(1400), s(976), s(1495)), radius=s(12), outline="#9aa1aa", width=s(3), fill="#f7f8fa")
    dot(draw, (976, 1448), 6)
    line(draw, [(976, 1448), (1010, 1448), (1010, 1418)])
    draw_text(draw, (1000, 1350), "侧边麦克风键", BLACK, LABEL_FONT)
    draw_text(draw, (1036, 1388), "Fn", BLUE, VALUE_FONT)


def centered_text(draw: ImageDraw.ImageDraw, y: int, text: str, fill: str, image_font: ImageFont.ImageFont) -> None:
    draw_text(draw, ((WIDTH - text_width(draw, text, image_font)) / 2, y), text, fill, image_font)


def save_svg() -> None:
    """写一个轻量 SVG 包装文件，方便文档里引用同一张图。"""
    OUT_SVG.write_text(
        """<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1600" viewBox="0 0 1200 1600">
  <image href="siri-remote-white-vibe-coding-map.png" width="1200" height="1600"/>
</svg>
""",
        encoding="utf-8",
    )


def main() -> None:
    base = Image.open(BASE_IMAGE)
    remote = crop_remote(base)
    remote_height = 1175
    remote_width = round(remote.width * remote_height / remote.height)
    remote = remote.resize((remote_width * SCALE, remote_height * SCALE), Image.LANCZOS)

    canvas = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), "#ffffff")
    draw = ImageDraw.Draw(canvas)

    centered_text(draw, 62, "Apple TV 遥控器按键映射图", BLACK, TITLE_FONT)
    draw.line((s(230), s(145), s(970), s(145)), fill=LIGHT_GRAY, width=s(2))

    remote_x = round((WIDTH - remote_width) / 2)
    remote_y = 175
    canvas.paste(remote, (remote_x * SCALE, remote_y * SCALE))

    # 以下坐标基于当前白底遥控器底图定位。
    target = {
        "up": (598, 310),
        "left": (485, 426),
        "right": (710, 426),
        "down": (598, 540),
        "confirm": (598, 426),
        "back": (537, 606),
        "home": (660, 607),
        "play": (537, 720),
        "mute": (537, 830),
        "volume": (660, 775),
        "touch": (598, 360),
    }

    annotation(draw, "left", 86, 288, "方向环上", ["上方向键"], target["up"])
    annotation(draw, "left", 86, 404, "方向环左", ["左方向键"], target["left"])
    annotation(draw, "left", 86, 500, "确认键", ["单击：Enter", "双击：开/关触摸板滑动"], target["confirm"])
    annotation(draw, "left", 86, 640, "返回键", ["单击：鼠标左键 + Enter", "双击：Control + ←"], target["back"])
    annotation(draw, "left", 86, 780, "播放/暂停", ["Space"], target["play"])
    annotation(draw, "left", 86, 900, "静音键", ["单击：删除", "长按：全选 + 删除"], target["mute"])

    annotation(draw, "right", 810, 338, "触摸面", ["滑动：鼠标移动"], target["touch"])
    annotation(draw, "right", 810, 404, "方向环右", ["右方向键"], target["right"])
    annotation(draw, "right", 810, 510, "方向环下", ["下方向键"], target["down"])
    annotation(draw, "right", 810, 645, "Home 键", ["单击：鼠标右键", "双击：Control + →"], target["home"])
    annotation(draw, "right", 810, 815, "音量键", ["音量 +：向上滚动", "音量 -：向下滚动"], target["volume"])

    draw_side_inset(draw)

    canvas = canvas.resize((WIDTH, HEIGHT), Image.LANCZOS)
    canvas.save(OUT_PNG)
    save_svg()
    print(f"saved {OUT_PNG}")
    print(f"saved {OUT_SVG}")


if __name__ == "__main__":
    main()
