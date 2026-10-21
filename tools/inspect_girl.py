import bpy

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

glb_path = r"D:\Meng's Workspace\Godot\Ego\assets\characters\anime-girl\girl.glb"
bpy.ops.import_scene.gltf(filepath=glb_path)

# 列出所有材质
print("=== MATERIALS ===")
for mat in bpy.data.materials:
    print(f"MAT: {mat.name}")

# 列出mesh及其材质slot
print("=== MESH SLOTS ===")
for obj in bpy.context.scene.objects:
    if obj.type == 'MESH':
        print(f"MESH: {obj.name}")
        for i, slot in enumerate(obj.material_slots):
            mname = slot.material.name if slot.material else "None"
            print(f"  slot[{i}]: {mname}")
