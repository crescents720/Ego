import bpy
import os

src_dir = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\source"
out_dir = r"D:\Meng's Workspace\Godot\Ego\artifacts\tex_preview"
os.makedirs(out_dir, exist_ok=True)

for f in sorted(os.listdir(src_dir)):
    if f.endswith('.tga'):
        path = os.path.join(src_dir, f)
        try:
            img = bpy.data.images.load(path)
            if img.size[0] == 0:
                print(f"EMPTY: {f}")
                continue
            png_name = f.replace('.tga', '.png')
            img.filepath_raw = os.path.join(out_dir, png_name)
            img.save()
            print(f"SAVED: {png_name} ({img.size[0]}x{img.size[1]})")
        except Exception as e:
            print(f"FAIL: {f} - {e}")
