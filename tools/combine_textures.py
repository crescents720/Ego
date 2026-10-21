import bpy
import os

tex_dir = r"D:\Meng's Workspace\Godot\Ego\artifacts\tex_preview"
out_path = r"D:\Meng's Workspace\Godot\Ego\artifacts\tex_all.png"

files = sorted([f for f in os.listdir(tex_dir) if f.endswith('.png')])
print("Files:", files)

# 用 Blender 的图像拼接：创建一个大图像，把每个贴图贴上去
# 简单方式：用 Pillow
try:
    from PIL import Image
    imgs = [Image.open(os.path.join(tex_dir, f)) for f in files]
    w = max(i.width for i in imgs)
    h = max(i.height for i in imgs)
    cols = 3
    rows = (len(imgs) + cols - 1) // cols
    canvas = Image.new('RGB', (w * cols, h * rows), (40, 40, 40))
    for i, img in enumerate(imgs):
        r = i // cols
        c = i % cols
        canvas.paste(img, (c * w, r * h))
    canvas.save(out_path)
    print(f"COMBINED: {out_path}")
except ImportError:
    print("Pillow not available, using Blender compositor")
