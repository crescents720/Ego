import bpy
import os
from mathutils import Vector, Euler
import math

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

glb_path = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\girl.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

mesh_obj = None
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        mesh_obj = obj
        break

min_x = min_y = min_z = 1e9
max_x = max_y = max_z = -1e9
for corner in mesh_obj.bound_box:
    world = mesh_obj.matrix_world @ Vector(corner)
    min_x = min(min_x, world.x); max_x = max(max_x, world.x)
    min_y = min(min_y, world.y); max_y = max(max_y, world.y)
    min_z = min(min_z, world.z); max_z = max(max_z, world.z)
h = max_z - min_z
cx = (min_x + max_x)/2; cy = (min_y + max_y)/2

# 创建armature
bpy.ops.object.armature_add(location=(cx, cy, min_z))
arm = bpy.context.active_object
arm.name = "Armature"
bpy.ops.object.mode_set(mode='EDIT')
eb = arm.data.edit_bones
for b in list(eb):
    eb.remove(b)

def zf(f): return min_z + h * f

bones_def = [
    ("pelvis",   (cx, cy, zf(0.55)), (cx, cy, zf(0.62)), None),
    ("spine",    (cx, cy, zf(0.62)), (cx, cy, zf(0.78)), "pelvis"),
    ("neck",     (cx, cy, zf(0.78)), (cx, cy, zf(0.85)), "spine"),
    ("head",     (cx, cy, zf(0.85)), (cx, cy, zf(0.97)), "neck"),
    ("shoulder.L", (cx-0.10, cy, zf(0.78)), (cx-0.18, cy, zf(0.76)), "spine"),
    ("arm.L",      (cx-0.18, cy, zf(0.76)), (cx-0.28, cy, zf(0.55)), "shoulder.L"),
    ("forearm.L",  (cx-0.28, cy, zf(0.55)), (cx-0.30, cy, zf(0.38)), "arm.L"),
    ("hand.L",     (cx-0.30, cy, zf(0.38)), (cx-0.31, cy, zf(0.30)), "forearm.L"),
    ("shoulder.R", (cx+0.10, cy, zf(0.78)), (cx+0.18, cy, zf(0.76)), "spine"),
    ("arm.R",      (cx+0.18, cy, zf(0.76)), (cx+0.28, cy, zf(0.55)), "shoulder.R"),
    ("forearm.R",  (cx+0.28, cy, zf(0.55)), (cx+0.30, cy, zf(0.38)), "arm.R"),
    ("hand.R",     (cx+0.30, cy, zf(0.38)), (cx+0.31, cy, zf(0.30)), "forearm.R"),
    ("thigh.L",    (cx-0.08, cy, zf(0.55)), (cx-0.09, cy, zf(0.30)), "pelvis"),
    ("shin.L",     (cx-0.09, cy, zf(0.30)), (cx-0.08, cy, zf(0.08)), "thigh.L"),
    ("foot.L",     (cx-0.08, cy, zf(0.08)), (cx-0.08, cy-0.05, zf(0.02)), "shin.L"),
    ("thigh.R",    (cx+0.08, cy, zf(0.55)), (cx+0.09, cy, zf(0.30)), "pelvis"),
    ("shin.R",     (cx+0.09, cy, zf(0.30)), (cx+0.08, cy, zf(0.08)), "thigh.R"),
    ("foot.R",     (cx+0.08, cy, zf(0.08)), (cx+0.08, cy-0.05, zf(0.02)), "shin.R"),
]

created = {}
for name, head, tail, parent in bones_def:
    b = eb.new(name)
    b.head = head
    b.tail = tail
    if parent:
        b.parent = created[parent]
    created[name] = b

bpy.ops.object.mode_set(mode='OBJECT')

# 手动创建顶点组并分配权重（按最近骨头）
# 先创建所有顶点组
for bone_name in created:
    if bone_name not in mesh_obj.vertex_groups:
        mesh_obj.vertex_groups.new(name=bone_name)

# 计算每个骨头的世界位置，把顶点分配给最近的骨头
bone_world_pos = {}
for bone_name, bone in created.items():
    # 骨头中点的世界坐标
    mid = (bone.head + bone.tail) / 2
    bone_world_pos[bone_name] = mesh_obj.matrix_world.inverted() @ arm.matrix_world @ mid

# 遍历所有顶点，找最近骨头
for v in mesh_obj.data.vertices:
    vpos = v.co
    best_bone = None
    best_dist = 1e9
    for bone_name, bpos in bone_world_pos.items():
        d = (vpos - bpos).length
        if d < best_dist:
            best_dist = d
            best_bone = bone_name
    if best_bone:
        mesh_obj.vertex_groups[best_bone].add([v.index], 1.0, 'REPLACE')

# 添加Armature修改器
mod = mesh_obj.modifiers.new(name="Armature", type='ARMATURE')
mod.object = arm
mod.use_vertex_groups = True

print("Skin added. Modifiers:", [m.type for m in mesh_obj.modifiers])

# 做走路动画（需要进入Pose Mode）
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')

arm.animation_data_create()
anim = bpy.data.actions.new(name="Walk")
arm.animation_data.action = anim

def set_bone(bone_name, frame, rx):
    pb = arm.pose.bones[bone_name]
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = Euler((math.radians(rx), 0, 0))
    pb.keyframe_insert("rotation_euler", frame=frame)

set_bone("thigh.L", 0, 25)
set_bone("shin.L", 0, -30)
set_bone("thigh.R", 0, -25)
set_bone("shin.R", 0, 10)
set_bone("arm.L", 0, -20)
set_bone("arm.R", 0, 20)
set_bone("thigh.L", 15, -25)
set_bone("shin.L", 15, 10)
set_bone("thigh.R", 15, 25)
set_bone("shin.R", 15, -30)
set_bone("arm.L", 15, 20)
set_bone("arm.R", 15, -20)
set_bone("thigh.L", 30, 25)
set_bone("shin.L", 30, -30)
set_bone("thigh.R", 30, -25)
set_bone("shin.R", 30, 10)
set_bone("arm.L", 30, -20)
set_bone("arm.R", 30, 20)

bpy.ops.object.mode_set(mode='OBJECT')

out_path = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\girl_rigged.glb"
bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format='GLB',
    use_selection=False,
    export_apply=True,
    export_animations=True,
)
print(f"EXPORTED: {out_path}")
