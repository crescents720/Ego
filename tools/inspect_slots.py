import bpy
import os
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

src_dir = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\source"
bpy.ops.wm.obj_import(filepath=os.path.join(src_dir, "girl.obj"))

# 给每个 slot 赋一个明显不同的纯色
colors = [
    (1, 0, 0, 1),    # 0 红
    (0, 1, 0, 1),    # 1 绿
    (0, 0, 1, 1),    # 2 蓝
    (1, 1, 0, 1),    # 3 黄
    (1, 0, 1, 1),    # 4 紫
    (0, 1, 1, 1),    # 5 青
]

for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        for i, slot in enumerate(obj.material_slots):
            if slot.material and i < len(colors):
                mat = slot.material
                mat.use_nodes = True
                nt = mat.node_tree
                nt.nodes.clear()
                out = nt.nodes.new("ShaderNodeOutputMaterial")
                bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
                bsdf.inputs["Base Color"].default_value = colors[i]
                nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

# 缩放
scale_factor = 1.55 / 61.57
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        obj.scale = (scale_factor, scale_factor, scale_factor)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

# 相机
min_x = min_y = min_z = 1e9
max_x = max_y = max_z = -1e9
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_x = min(min_x, world.x); max_x = max(max_x, world.x)
            min_y = min(min_y, world.y); max_y = max(max_y, world.y)
            min_z = min(min_z, world.z); max_z = max(max_z, world.z)
cx = (min_x + max_x) / 2; cy = (min_y + max_y) / 2; cz = (min_z + max_z) / 2
h = max_z - min_z

bpy.ops.object.camera_add(location=(cx + h*0.9, cy - h*1.2, cz))
cam = bpy.context.active_object
direction = Vector((cx, cy, cz)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.camera = cam

bpy.ops.object.light_add(type='AREA', location=(cx, cy - 1.5, cz + 1))
key = bpy.context.active_object
key.data.energy = 300
direction = Vector((cx, cy, cz)) - key.location
key.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.2, 0.25, 1)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 512
scene.render.resolution_y = 768
scene.render.filepath = r"D:\Meng's Workspace\Godot\Ego\artifacts\girl_slots.png"
os.makedirs(os.path.dirname(scene.render.filepath), exist_ok=True)
bpy.ops.render.render(write_still=True)
print("RENDERED")
