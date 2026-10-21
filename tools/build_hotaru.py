import bpy
import os

# 清空场景
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# ---------- 材质 ----------
def make_mat(name, color, roughness=0.55):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat

skin      = make_mat("Skin",      (0.98, 0.82, 0.72, 1.0))
hair_mat  = make_mat("Hair",      (0.88, 0.91, 0.95, 1.0))
shirt_mat = make_mat("Shirt",     (0.97, 0.96, 0.93, 1.0))
skirt_mat = make_mat("Skirt",     (0.10, 0.10, 0.13, 1.0))
shoe_mat  = make_mat("Shoe",      (0.96, 0.95, 0.93, 1.0))
shoe_acc  = make_mat("ShoeAccent",(0.92, 0.55, 0.58, 1.0))
eye_mat   = make_mat("Eye",       (0.15, 0.35, 0.60, 1.0))
eye_white = make_mat("EyeWhite",  (1.0, 1.0, 1.0, 1.0))
pupil     = make_mat("Pupil",     (0.05, 0.10, 0.25, 1.0))
mouth_mat = make_mat("Mouth",     (0.85, 0.35, 0.35, 1.0))
ribbon_m  = make_mat("Ribbon",    (0.05, 0.05, 0.07, 1.0))
cheek_mat = make_mat("Cheek",     (1.0, 0.65, 0.65, 1.0))

# ---------- 工具 ----------
def add_sphere(name, loc, scale, mat, subdiv=2):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if mat:
        obj.data.materials.append(mat)
    if subdiv > 0:
        mod = obj.modifiers.new("Subsurf", 'SUBSURF')
        mod.levels = subdiv
        mod.render_levels = subdiv
    return obj

def add_cube(name, loc, scale, mat, bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", 'BEVEL')
        mod.width = bevel
        mod.segments = 3
    return obj

# ============================================================
# 萌系化：总高 ~1.45m，5.5 头身，大眼圆脸娇小可爱
# ============================================================

# ---------- 身体 ----------
add_sphere("Hips",   (0, 0, 0.70), (0.15, 0.11, 0.10), skin)
add_sphere("Waist", (0, 0, 0.85), (0.12, 0.095, 0.09), skin)
add_sphere("Chest", (0, 0, 0.98), (0.15, 0.10, 0.13), skin)

bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.07, location=(0, 0, 1.13))
neck = bpy.context.active_object
neck.name = "Neck"
neck.data.materials.append(skin)

# 头（放大、圆短，萌系）
add_sphere("Head", (0, 0, 1.32), (0.155, 0.145, 0.16), skin)

# 眼睛（大而圆，带眼白+瞳孔+高光）
# 左眼
add_sphere("EyeWhiteL", (-0.055, -0.130, 1.34), (0.035, 0.015, 0.040), eye_white, subdiv=1)
add_sphere("PupilL",    (-0.055, -0.142, 1.34), (0.020, 0.010, 0.026), pupil, subdiv=1)
# 右眼
add_sphere("EyeWhiteR", ( 0.055, -0.130, 1.34), (0.035, 0.015, 0.040), eye_white, subdiv=1)
add_sphere("PupilR",    ( 0.055, -0.142, 1.34), (0.020, 0.010, 0.026), pupil, subdiv=1)
# 高光（小白点）
add_sphere("SparkleL", (-0.060, -0.150, 1.355), (0.007, 0.005, 0.009), eye_white, subdiv=0)
add_sphere("SparkleR", ( 0.050, -0.150, 1.355), (0.007, 0.005, 0.009), eye_white, subdiv=0)

# 小嘴（红点）
add_sphere("Mouth", (0, -0.148, 1.25), (0.018, 0.006, 0.010), mouth_mat, subdiv=1)

# 腮红（两团淡粉）
add_sphere("CheekL", (-0.085, -0.125, 1.28), (0.025, 0.005, 0.015), cheek_mat, subdiv=1)
add_sphere("CheekR", ( 0.085, -0.125, 1.28), (0.025, 0.005, 0.015), cheek_mat, subdiv=1)

# ---------- 腿（短一点，幼态）----------
add_sphere("ThighL",  (-0.075, 0,     0.50), (0.06, 0.065, 0.14), skin)
add_sphere("ThighR",  ( 0.075, 0,     0.50), (0.06, 0.065, 0.14), skin)
add_sphere("CalfL",   (-0.075, 0.005, 0.26), (0.045, 0.05, 0.13), skin)
add_sphere("CalfR",   ( 0.075, 0.005, 0.26), (0.045, 0.05, 0.13), skin)
# 鞋
add_cube("ShoeL",      (-0.075, -0.025,  0.05), (0.045, 0.085, 0.035), shoe_mat, bevel=0.018)
add_cube("ShoeR",      ( 0.075, -0.025,  0.05), (0.045, 0.085, 0.035), shoe_mat, bevel=0.018)
add_cube("ShoeTipL",   (-0.075, -0.100, 0.05), (0.045, 0.018, 0.030), shoe_acc, bevel=0.012)
add_cube("ShoeTipR",   ( 0.075, -0.100, 0.05), (0.045, 0.018, 0.030), shoe_acc, bevel=0.012)

# ---------- 手臂（微张，短）----------
add_sphere("UpperArmL", (-0.19, 0, 1.02), (0.04, 0.045, 0.12), skin)
add_sphere("UpperArmR", ( 0.19, 0, 1.02), (0.04, 0.045, 0.12), skin)
add_sphere("ForearmL",  (-0.24, 0, 0.82), (0.032, 0.035, 0.11), skin)
add_sphere("ForearmR",  ( 0.24, 0, 0.82), (0.032, 0.035, 0.11), skin)
add_sphere("HandL",     (-0.26, 0, 0.70), (0.030, 0.035, 0.05), skin, subdiv=1)
add_sphere("HandR",     ( 0.26, 0, 0.70), (0.030, 0.035, 0.05), skin, subdiv=1)

# ---------- 服装 ----------
# T恤
add_sphere("ShirtBody", (0, 0, 0.96), (0.165, 0.115, 0.15), shirt_mat)
add_sphere("SleeveL",   (-0.175, 0, 1.02), (0.05, 0.05, 0.07), shirt_mat, subdiv=1)
add_sphere("SleeveR",   ( 0.175, 0, 1.02), (0.05, 0.05, 0.07), shirt_mat, subdiv=1)

# 短裙
bpy.ops.mesh.primitive_cone_add(radius1=0.18, radius2=0.12, depth=0.18, location=(0, 0, 0.72))
skirt = bpy.context.active_object
skirt.name = "Skirt"
skirt.data.materials.append(skirt_mat)
mod = skirt.modifiers.new("Subsurf", 'SUBSURF')
mod.levels = 1

# ---------- 头发（蓬松分片）----------
# 后脑主发块（更大更蓬，垂到肩下）
add_sphere("HairBack",    (0,     0.05, 1.30), (0.16, 0.11, 0.22), hair_mat)
# 两侧鬓发（更长垂到下巴）
add_sphere("HairSideL",  (-0.125,-0.03, 1.25), (0.045, 0.04, 0.16), hair_mat, subdiv=1)
add_sphere("HairSideR",  ( 0.125,-0.03, 1.25), (0.045, 0.04, 0.16), hair_mat, subdiv=1)
# 头顶高马尾束
add_sphere("HairBun",    (0,     0.03, 1.52), (0.065, 0.06, 0.065), hair_mat, subdiv=1)
# 马尾垂下一束（更长）
add_sphere("HairPonytail",(0,    0.12, 1.32), (0.055, 0.055, 0.25), hair_mat, subdiv=1)
# 额前刘海（小片片）
add_sphere("Bang1", (-0.06, -0.12, 1.43), (0.04, 0.02, 0.05), hair_mat, subdiv=1)
add_sphere("Bang2", ( 0.00, -0.13, 1.44), (0.045, 0.02, 0.05), hair_mat, subdiv=1)
add_sphere("Bang3", ( 0.06, -0.12, 1.43), (0.04, 0.02, 0.05), hair_mat, subdiv=1)

# 黑丝带
add_cube("RibbonL", (-0.13, -0.09, 1.32), (0.012, 0.005, 0.05), ribbon_m, bevel=0.005)
add_cube("RibbonR", ( 0.13, -0.09, 1.32), (0.012, 0.005, 0.05), ribbon_m, bevel=0.005)

# ---------- 导出 ----------
out_dir = r"D:\Meng's Workspace\Godot\Ego\assets\characters"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "hotaru.glb")

bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format='GLB',
    use_selection=False,
    export_apply=True,
)
print(f"EXPORTED: {out_path}")
