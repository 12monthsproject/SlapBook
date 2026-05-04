#!/usr/bin/env python3
"""
创建 macOS icns 图标文件
"""

import sys
from pathlib import Path
from PIL import Image

def create_icns(input_path, output_path):
    """从图片创建 icns 文件"""
    img = Image.open(input_path)
    
    # 确保是 RGBA 模式
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
    
    # macOS 图标尺寸
    sizes = [16, 32, 128, 256, 512]
    
    # 创建临时目录存储各尺寸图标
    import tempfile
    import shutil
    import struct
    
    temp_dir = tempfile.mkdtemp()
    iconset_dir = Path(temp_dir) / "icon.iconset"
    iconset_dir.mkdir()
    
    try:
        # 生成各尺寸图标
        for size in sizes:
            # 1x 版本
            resized = img.resize((size, size), Image.LANCZOS)
            resized.save(iconset_dir / f"icon_{size}x{size}.png", 'PNG')
            
            # 2x 版本
            resized2x = img.resize((size*2, size*2), Image.LANCZOS)
            resized2x.save(iconset_dir / f"icon_{size}x{size}@2x.png", 'PNG')
        
        # 使用 iconutil 转换
        import subprocess
        result = subprocess.run(
            ['iconutil', '-c', 'icns', str(iconset_dir), '-o', str(output_path)],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print(f"iconutil failed: {result.stderr}")
            # 回退：直接复制最大尺寸作为图标
            img.save(output_path.replace('.icns', '.png'), 'PNG')
            return False
        
        return True
        
    finally:
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: create_icon.py <input.jpg> <output.icns>")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    if create_icns(input_path, output_path):
        print(f"✅ 图标创建成功: {output_path}")
    else:
        print(f"⚠️  使用备用方案")
        # 直接复制原图作为图标
        from PIL import Image
        img = Image.open(input_path)
        img.save(output_path.replace('.icns', '.png'))
