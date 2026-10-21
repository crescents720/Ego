import bpy
import os
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

glb_path = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\girl_rigged.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

arm = None
mesh = None
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        arm = obj
    if obj.type == 'MESH':
        mesh = obj

print("Armature:", arm.name if arm else "NONE")
print("Mesh:", mesh.name if mesh else "NONE")

if arm and arm.animation_data and arm.animation_data.action:
    print("Action:", arm.animation_data.action.name)
else:
    print("NO ACTION")

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
cx = (min_x+max_x)/2; cy = (min_y+max_y)/2; cz = (min_z+max_z)/2
h = max_z - min_z

bpy.ops.object.camera_add(location=(cx + h*0.8, cy - h*1.2, cz))
cam = bpy.context.active_object
direction = Vector((cx, cy, cz)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.camera = cam

bpy.ops.object.light_add(type='AREA', location=(cx, cy-1.5, cz+1))
key = bpy.context.active_object
key.data.energy = 400
direction = Vector((cx, cy, cz)) - key.location
key.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

world = bpy.context.scene.world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.2, 0.25, 1)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 400
scene.render.resolution_y = 600

# 帧0
scene.frame_set(0)
pb = arm.pose.bones["thigh.L"]
print(f"Frame0 thigh.L rot: {pb.rotation_euler}")
scene.render.filepath = r"D:\Meng's Workspace\Godot\Ego\artifacts\rig_f0.png"
bpy.ops.render.render(write_still=True)

# 帧15
scene.frame_set(15)
pb = arm.pose.bones["thigh.L"]
print(f"Frame15 thigh.L rot: {pb.rotation_euler}")
scene.render.filepath = r"D:\Meng's Workspace\Godot\Ego\artifacts\rig_f15.png"
bpy.ops.render.render(write_still=True)
print("RENDERED")
