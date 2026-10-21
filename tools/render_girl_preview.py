import bpy
import os
import math
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

glb_path = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\girl.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

# 包围盒
min_x = min_y = min_z = 1e9
max_x = max_y = max_z = -1e9
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            min_x = min(min_x, world.x); max_x = max(max_x, world.x)
            min_y = min(min_y, world.y); max_y = max(max_y, world.y)
            min_z = min(min_z, world.z); max_z = max(max_z, world.z)

cx = (min_x + max_x) / 2
cy = (min_y + max_y) / 2
cz = (min_z + max_z) / 2
h = max_z - min_z

# 相机
bpy.ops.object.camera_add(location=(cx + h*0.9, cy - h*1.2, cz + h*0.1))
cam = bpy.context.active_object
direction = Vector((cx, cy, cz)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.camera = cam

# 灯
bpy.ops.object.light_add(type='AREA', location=(cx, cy - 1.5, cz + 1.5))
key = bpy.context.active_object
key.data.energy = 200
key.data.size = 2
direction = Vector((cx, cy, cz)) - key.location
key.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

bpy.ops.object.light_add(type='SUN', location=(0, 0, 3))
sun = bpy.context.active_object
sun.data.energy = 1.5

# 背景
world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.78, 0.85, 1)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 512
scene.render.resolution_y = 768
scene.render.filepath = r"D:\Meng's Workspace\Godot\Ego\artifacts\girl_v3.png"
os.makedirs(os.path.dirname(scene.render.filepath), exist_ok=True)
bpy.ops.render.render(write_still=True)
print("RENDERED")
