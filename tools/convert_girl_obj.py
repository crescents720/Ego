import bpy
import os
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

src_dir = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\source"

tex_body  = os.path.join(src_dir, "Tex_0024_0out.tga")
tex_hair  = os.path.join(src_dir, "Tex_0026_0out.tga")
tex_face  = os.path.join(src_dir, "Tex_0027_0out.tga")
tex_eye   = os.path.join(src_dir, "Tex_0028_0out.tga")

bpy.ops.wm.obj_import(filepath=os.path.join(src_dir, "girl.obj"))

def set_albedo(mat, image_path, tint=None):
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    if image_path and os.path.exists(image_path):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image_path)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if tint:
        bsdf.inputs["Base Color"].default_value = tint
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 0.6

# slot[0] 身体 = 全身贴图
# slot[1] 头发 = 纯黑
# slot[2] 脸 = 脸贴图
# slot[3] 眼睛 = 眼睛贴图
# slot[4] 头发侧缕 = 纯黑
assignments = {
    0: (tex_body, None),
    1: (None, (0.05, 0.05, 0.07, 1)),
    2: (tex_face, None),
    3: (tex_eye, None),
    4: (None, (0.05, 0.05, 0.07, 1)),
}

for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        for slot_idx, (tex_path, tint) in assignments.items():
            if slot_idx < len(obj.material_slots):
                slot = obj.material_slots[slot_idx]
                if slot.material:
                    set_albedo(slot.material, tex_path, tint)

# 缩放
scale_factor = 1.55 / 61.57
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        obj.scale = (scale_factor, scale_factor, scale_factor)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

out_path = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\girl.glb"
bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format='GLB',
    use_selection=False,
    export_apply=True,
)
print(f"EXPORTED: {out_path}")
