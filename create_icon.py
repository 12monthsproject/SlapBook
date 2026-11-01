#!/usr/bin/env python3
"""
创建 macOS icns 图标文件

按 macOS Big Sur 之后的规范：圆角方块只占画布约 80%，四周留透明边距。
（铺满画布会让图标在 Dock / Launchpad 里明显比其他 app 大一圈）
"""

import sys
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

CONTENT_RATIO = 0.80      # 内容占画布比例
CORNER_RATIO = 0.2237     # 圆角半径占内容方块比例（近似苹果 squircle）


def make_icon(img, size):
    """把原图缩到画布的 80% 居中，加圆角后输出 size×size 透明画布图标"""
    content_size = max(1, int(round(size * CONTENT_RATIO)))
    content = img.resize((content_size, content_size), Image.LANCZOS)

    radius = int(round(content_size * CORNER_RATIO))
    mask = Image.new("L", (content_size, content_size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, content_size - 1, content_size - 1], radius=radius, fill=255
    )

    # 与原图透明通道相乘，保留原本的透明区域
    alpha = ImageChops.multiply(content.getchannel("A"), mask)
    content.putalpha(alpha)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - content_size) // 2, (size - content_size) // 2)
    canvas.paste(content, offset, content)
    return canvas


def create_icns(input_path, output_path):
    """从图片创建 icns 文件"""
    img = Image.open(input_path)
    if img.mode != "RGBA":
        img = img.convert("RGBA")

    # iconset 需要的尺寸（1x / 2x 自动覆盖到 1024）
    sizes = [16, 32, 128, 256, 512]

    temp_dir = tempfile.mkdtemp()
    iconset_dir = Path(temp_dir) / "icon.iconset"
    iconset_dir.mkdir()

    try:
        for size in sizes:
            make_icon(img, size).save(iconset_dir / f"icon_{size}x{size}.png", "PNG")
            make_icon(img, size * 2).save(iconset_dir / f"icon_{size}x{size}@2x.png", "PNG")

        result = subprocess.run(
            ["iconutil", "-c", "icns", str(iconset_dir), "-o", str(output_path)],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(f"iconutil failed: {result.stderr}")
            # 回退：直接导出最大尺寸 PNG，方便手动处理
            img.save(str(output_path).replace(".icns", ".png"), "PNG")
            return False
        return True
    finally:
        shutil.rmtree(temp_dir)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: create_icon.py <input.png> <output.icns>")
        sys.exit(1)

    src, dst = sys.argv[1], sys.argv[2]
    if create_icns(src, dst):
        print(f"✅ 图标创建成功: {dst}")
    else:
        print("⚠️  已回退为 PNG 输出")
