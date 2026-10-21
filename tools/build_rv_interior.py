"""Build the original, editable RV interior for Ego: Firefly Road.

The geometry and materials in this script are original. The Girls' Frontline 2
dormitory archive supplied by the user is used only as a mood/reference study;
none of its meshes or textures are imported or redistributed.
"""

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
GLB_PATH = ROOT / "assets" / "models" / "rv_interior_initial.glb"
BLEND_PATH = ROOT / "source" / "rv_interior_initial.blend"
PREVIEW_PATH = ROOT / "artifacts" / "rv_interior_initial.png"


def material(name, color, metallic=0.0, roughness=0.55, emission=None, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Alpha"].default_value = alpha
    if emission is not None:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = (*emission, 1.0)
        strength_input = bsdf.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = 3.5
    if alpha < 1.0:
        mat.surface_render_method = "DITHERED"
        mat.use_transparency_overlap = False
    return mat


def move_to_collection(obj, collection):
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)


def box(name, size, location, mat, collection, bevel=0.035, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj


def cylinder(name, radius, depth, location, mat, collection, rotation=(0.0, 0.0, 0.0), vertices=24, bevel=0.02):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    if bevel:
        modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj


def sphere(name, scale, location, mat, collection):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj


def torus(name, major_radius, minor_radius, location, mat, collection, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=32,
        minor_segments=8,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    move_to_collection(obj, collection)
    return obj


def empty_socket(name, location, slot_type, collection, rotation=(0.0, 0.0, 0.0)):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "CUBE"
    obj.empty_display_size = 0.28
    obj.location = location
    obj.rotation_euler = rotation
    obj["ego_slot_type"] = slot_type
    obj["ego_initial_state"] = "empty"
    collection.objects.link(obj)
    return obj


def add_cabinet(name, location, size, body_mat, door_mat, metal_mat, collection, doors=2, front_axis="X"):
    body = box(name + "_Body", size, location, body_mat, collection, 0.045)
    body["ego_module"] = name
    if front_axis == "X":
        front_x = location[0] + size[0] / 2.0 + 0.016
        door_width = size[1] / doors - 0.025
        for index in range(doors):
            y = location[1] - size[1] / 2.0 + door_width / 2.0 + index * (size[1] / doors)
            box(f"{name}_Door_{index + 1}", (0.035, door_width, size[2] - 0.08), (front_x, y, location[2]), door_mat, collection, 0.02)
            box(f"{name}_Handle_{index + 1}", (0.055, 0.18, 0.035), (front_x + 0.035, y, location[2] + 0.12), metal_mat, collection, 0.012)
    else:
        front_y = location[1] - size[1] / 2.0 - 0.016
        door_width = size[0] / doors - 0.025
        for index in range(doors):
            x = location[0] - size[0] / 2.0 + door_width / 2.0 + index * (size[0] / doors)
            box(f"{name}_Door_{index + 1}", (door_width, 0.035, size[2] - 0.08), (x, front_y, location[2]), door_mat, collection, 0.02)
            box(f"{name}_Handle_{index + 1}", (0.18, 0.055, 0.035), (x, front_y - 0.035, location[2] + 0.12), metal_mat, collection, 0.012)
    return body


def add_book(name, location, size, mat, collection, rotation_z=0.0):
    return box(name, size, location, mat, collection, 0.012, rotation=(0.0, 0.0, rotation_z))


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


bpy.ops.wm.read_factory_settings(use_empty=True)
for path in (GLB_PATH.parent, BLEND_PATH.parent, PREVIEW_PATH.parent):
    path.mkdir(parents=True, exist_ok=True)

scene_root = bpy.data.collections.new("RV_INTERIOR_INITIAL")
bpy.context.scene.collection.children.link(scene_root)
collections = {}
for name in [
    "01_Architecture",
    "02_Sleeping",
    "03_Galley",
    "04_Dinette",
    "05_Workbench",
    "06_Storage_Utilities",
    "07_Decor",
    "08_Upgrade_Sockets",
    "09_Cockpit",
]:
    collection = bpy.data.collections.new(name)
    scene_root.children.link(collection)
    collections[name] = collection

architecture = collections["01_Architecture"]
sleeping = collections["02_Sleeping"]
galley = collections["03_Galley"]
dinette = collections["04_Dinette"]
workbench = collections["05_Workbench"]
utilities = collections["06_Storage_Utilities"]
decor = collections["07_Decor"]
sockets = collections["08_Upgrade_Sockets"]
cockpit = collections["09_Cockpit"]

# Original palette: warm lived-in surfaces nested inside a cool industrial shell.
mat_shell = material("M_Shell_Ivory", (0.69, 0.70, 0.66), metallic=0.1, roughness=0.58)
mat_shell_dark = material("M_Shell_Dark", (0.085, 0.105, 0.115), metallic=0.46, roughness=0.38)
mat_floor = material("M_Floor_Rubber", (0.12, 0.145, 0.145), metallic=0.05, roughness=0.84)
mat_wood = material("M_Wood_Warm", (0.37, 0.20, 0.105), roughness=0.64)
mat_wood_light = material("M_Wood_Light", (0.59, 0.39, 0.22), roughness=0.68)
mat_cabinet = material("M_Cabinet_Sage", (0.25, 0.36, 0.33), metallic=0.03, roughness=0.57)
mat_counter = material("M_Counter_Composite", (0.71, 0.66, 0.54), roughness=0.4)
mat_metal = material("M_Brushed_Metal", (0.37, 0.42, 0.43), metallic=0.82, roughness=0.28)
mat_black = material("M_Black_Glass", (0.018, 0.024, 0.026), metallic=0.15, roughness=0.16)
mat_glass = material("M_Window_Smoke", (0.12, 0.24, 0.28), metallic=0.0, roughness=0.12, alpha=0.32)
mat_fabric = material("M_Fabric_Teal", (0.12, 0.31, 0.32), roughness=0.94)
mat_bedding = material("M_Bedding_Cream", (0.77, 0.68, 0.54), roughness=0.96)
mat_blanket = material("M_Blanket_Rust", (0.55, 0.20, 0.105), roughness=0.98)
mat_accent = material("M_Safety_Orange", (0.86, 0.31, 0.075), metallic=0.12, roughness=0.46)
mat_cyan = material("M_Interface_Cyan", (0.04, 0.48, 0.56), metallic=0.25, roughness=0.25, emission=(0.03, 0.48, 0.62))
mat_light = material("M_Warm_LED", (1.0, 0.72, 0.38), roughness=0.2, emission=(1.0, 0.38, 0.08))
mat_screen = material("M_Screen", (0.025, 0.15, 0.18), metallic=0.2, roughness=0.16, emission=(0.02, 0.48, 0.62))
mat_red = material("M_Medical_Red", (0.65, 0.08, 0.07), roughness=0.56)
mat_green = material("M_Plant", (0.12, 0.35, 0.19), roughness=0.86)
mat_paper = material("M_Paper", (0.78, 0.72, 0.58), roughness=0.95)
mat_seat = material("M_Cockpit_Seat", (0.095, 0.155, 0.16), roughness=0.90)
mat_dash = material("M_Dashboard", (0.055, 0.075, 0.078), metallic=0.12, roughness=0.52)
mat_indicator_green = material("M_Indicator_Green", (0.04, 0.48, 0.20), metallic=0.1, roughness=0.24, emission=(0.02, 0.55, 0.20))

# Architecture and cutaway shell.
# The original living box was 7.15 m long.  The +Y end now grows by 2.40 m
# into a walk-through cockpit, preserving the existing room coordinates.
box("FloorBase", (2.82, 9.55, 0.16), (0.0, 1.20, 0.02), mat_shell_dark, architecture, 0.12)
box("FloorInset", (2.54, 9.26, 0.06), (0.0, 1.20, 0.135), mat_floor, architecture, 0.05)
for y in [-2.68, -1.34, 0.0, 1.34, 2.68, 4.02, 5.36]:
    box(f"FloorCrossRail_{y:+.2f}", (2.62, 0.045, 0.025), (0.0, y, 0.18), mat_metal, architecture, 0.008)
for x in [-0.42, 0.42]:
    box(f"FloorLongRail_{x:+.2f}", (0.035, 9.12, 0.022), (x, 1.20, 0.181), mat_metal, architecture, 0.008)

# Lower shell panels, structural posts and window bands.
for x, side in [(-1.37, "L"), (1.37, "R")]:
    box(f"LowerWall_{side}", (0.12, 9.4, 0.68), (x, 1.20, 0.52), mat_shell, architecture, 0.04)
    box(f"UpperRail_{side}", (0.13, 9.4, 0.16), (x, 1.20, 2.31), mat_shell_dark, architecture, 0.035)
    for y in [-3.36, -1.72, -0.10, 1.52, 3.36]:
        box(f"WindowPost_{side}_{y:+.2f}", (0.15, 0.16, 1.64), (x, y, 1.52), mat_shell_dark, architecture, 0.03)
    for y in [-2.54, -0.91, 0.71, 2.44]:
        glass = box(f"WindowGlass_{side}_{y:+.2f}", (0.035, 1.40, 1.08), (x, y, 1.58), mat_glass, architecture, 0.035)
        glass["ego_toggle_for_cutaway"] = True

# Sleeping-end bulkhead and living-cabin ceiling ribs.
box("FrontBulkhead", (2.78, 0.14, 2.38), (0.0, -3.50, 1.25), mat_shell, architecture, 0.08)
box("FrontWindow", (1.62, 0.04, 0.64), (0.0, -3.58, 1.74), mat_glass, architecture, 0.1)
# A shallow header visually marks the old body/cab join without blocking the
# 1.5 m-wide walk-through opening or the portrait cutaway view.
box("CabTransitionHeader", (2.72, 0.13, 0.15), (0.0, 3.50, 2.31), mat_shell_dark, architecture, 0.035)
for x, side in [(-1.34, "L"), (1.34, "R")]:
    box(f"CabTransitionPost_{side}", (0.12, 0.13, 1.52), (x, 3.50, 1.51), mat_shell_dark, architecture, 0.028)
for y in [-2.72, -1.36, 0.0, 1.36, 2.72]:
    box(f"CeilingRib_{y:+.2f}", (2.72, 0.13, 0.13), (0.0, y, 2.43), mat_shell_dark, architecture, 0.035)
for x, side in [(-1.20, "L"), (1.20, "R")]:
    box(f"LEDChannel_{side}", (0.055, 5.72, 0.055), (x, -0.1, 2.29), mat_light, architecture, 0.01)

# Raised front sleeping alcove and accessible under-bed storage.
box("BedPlatform", (2.46, 1.72, 0.22), (0.0, -2.58, 0.72), mat_wood, sleeping, 0.08)
box("Mattress", (2.30, 1.58, 0.30), (0.0, -2.58, 0.95), mat_bedding, sleeping, 0.13)
box("Blanket", (2.22, 0.86, 0.09), (0.0, -2.89, 1.15), mat_blanket, sleeping, 0.045)
for x in [-0.64, 0.05, 0.72]:
    sphere(f"Pillow_{x:+.2f}", (0.42, 0.30, 0.13), (x, -2.06, 1.17), mat_bedding, sleeping)
for index, x in enumerate([-0.82, 0.0, 0.82]):
    add_cabinet(f"UnderBedDrawer_{index + 1}", (x, -1.79, 0.48), (0.72, 0.56, 0.52), mat_wood, mat_cabinet, mat_metal, sleeping, doors=1, front_axis="Y")
box("BedGuard", (2.38, 0.07, 0.27), (0.0, -1.71, 0.99), mat_metal, sleeping, 0.025)
box("BrotherPhotoFrame", (0.54, 0.06, 0.42), (-0.83, -3.40, 1.63), mat_wood_light, decor, 0.025, rotation=(math.radians(90), 0.0, 0.0))
box("BrotherPhoto", (0.43, 0.035, 0.31), (-0.83, -3.36, 1.63), mat_paper, decor, 0.012, rotation=(math.radians(90), 0.0, 0.0))
box("BedReadingLight", (0.30, 0.07, 0.09), (0.87, -3.39, 1.70), mat_light, sleeping, 0.025)

# Left galley: appliances, storage, sink, faucet and cooktop.
add_cabinet("GalleyBase", (-1.00, -0.27, 0.55), (0.63, 2.26, 0.78), mat_shell_dark, mat_cabinet, mat_metal, galley, doors=4)
box("GalleyCounter", (0.74, 2.34, 0.10), (-0.94, -0.27, 0.995), mat_counter, galley, 0.045)
box("SinkBasin", (0.46, 0.64, 0.055), (-0.91, 0.40, 1.045), mat_black, galley, 0.055)
for x, y, sx, sy in [(-1.14, 0.40, 0.05, 0.72), (-0.68, 0.40, 0.05, 0.72), (-0.91, 0.73, 0.48, 0.05), (-0.91, 0.07, 0.48, 0.05)]:
    box("SinkLip", (sx, sy, 0.04), (x, y, 1.075), mat_metal, galley, 0.012)
cylinder("FaucetStem", 0.035, 0.42, (-1.16, 0.62, 1.25), mat_metal, galley)
cylinder("FaucetSpout", 0.03, 0.32, (-1.02, 0.62, 1.43), mat_metal, galley, rotation=(0.0, math.radians(90), 0.0))
box("CooktopGlass", (0.56, 0.73, 0.035), (-0.90, -0.67, 1.064), mat_black, galley, 0.04)
for y, radius in [(-0.48, 0.17), (-0.82, 0.14)]:
    torus("InductionRing", radius, 0.012, (-0.90, y, 1.087), mat_cyan, galley)
add_cabinet("GalleyOverhead_A", (-1.12, -0.72, 1.91), (0.43, 1.14, 0.58), mat_shell_dark, mat_cabinet, mat_metal, galley, doors=2)
add_cabinet("GalleyOverhead_B", (-1.12, 0.48, 1.91), (0.43, 1.06, 0.58), mat_shell_dark, mat_cabinet, mat_metal, galley, doors=2)
box("FridgeDoor", (0.055, 0.58, 0.68), (-0.65, -1.03, 0.52), mat_shell, galley, 0.05)
box("FridgeDisplay", (0.025, 0.18, 0.10), (-0.615, -1.03, 0.68), mat_screen, galley, 0.015)
cylinder("KettleBody", 0.12, 0.22, (-0.92, 0.88, 1.18), mat_metal, decor)
torus("KettleHandle", 0.14, 0.022, (-0.92, 0.88, 1.29), mat_shell_dark, decor, rotation=(math.radians(90), 0.0, 0.0))

# Right dinette: benches, table and transformable sleeping surface.
for y, suffix in [(-0.72, "Front"), (0.70, "Rear")]:
    box(f"DinetteBenchBase_{suffix}", (0.72, 0.72, 0.46), (0.96, y, 0.42), mat_shell_dark, dinette, 0.08)
    box(f"DinetteSeat_{suffix}", (0.72, 0.72, 0.18), (0.96, y, 0.73), mat_fabric, dinette, 0.10)
    box(f"DinetteBack_{suffix}", (0.20, 0.70, 0.74), (1.22, y, 1.10), mat_fabric, dinette, 0.10)
cylinder("DinetteTablePedestal", 0.055, 0.62, (0.50, 0.0, 0.62), mat_metal, dinette)
box("DinetteTable", (0.78, 0.96, 0.08), (0.50, 0.0, 0.96), mat_wood_light, dinette, 0.08)
cylinder("TeaMug", 0.075, 0.12, (0.38, -0.18, 1.07), mat_bedding, decor, vertices=20)
torus("TeaMugHandle", 0.055, 0.012, (0.29, -0.18, 1.08), mat_bedding, decor, rotation=(0.0, math.radians(90), 0.0))
box("DinetteWallShelf", (0.26, 1.85, 0.10), (1.17, 0.0, 1.78), mat_wood, dinette, 0.035)

# Rear-left fabrication bench: initial hand tools only, with room for upgrades.
add_cabinet("WorkbenchBase", (-0.78, 2.15, 0.54), (0.88, 1.66, 0.74), mat_shell_dark, mat_cabinet, mat_metal, workbench, doors=3)
box("WorkbenchTop", (0.98, 1.78, 0.12), (-0.74, 2.15, 0.98), mat_wood_light, workbench, 0.045)
box("WorkbenchPegboard", (1.10, 0.08, 1.05), (-0.70, 3.35, 1.62), mat_shell_dark, workbench, 0.035)
for row in range(4):
    for col in range(6):
        cylinder(
            f"Peg_{row}_{col}",
            0.012,
            0.03,
            (-1.14 + col * 0.18, 3.29, 1.27 + row * 0.20),
            mat_metal,
            workbench,
            rotation=(math.radians(90), 0.0, 0.0),
            vertices=12,
            bevel=0.0,
        )
box("WorkbenchScreen", (0.62, 0.07, 0.38), (-0.77, 3.20, 1.78), mat_screen, workbench, 0.035)
box("WorkbenchKeyboard", (0.48, 0.23, 0.035), (-0.62, 2.50, 1.08), mat_black, workbench, 0.025, rotation=(math.radians(8), 0.0, 0.0))
for index, (x, y, rot) in enumerate([(-1.08, 1.76, -0.18), (-0.76, 1.82, 0.22), (-0.45, 1.74, -0.08)]):
    box(f"HandTool_{index + 1}", (0.08, 0.40, 0.06), (x, y, 1.10), mat_accent if index == 0 else mat_metal, workbench, 0.025, rotation=(0.0, 0.0, rot))
box("TaskLampBase", (0.24, 0.24, 0.06), (-1.00, 2.69, 1.11), mat_shell_dark, workbench, 0.025)
cylinder("TaskLampArm", 0.025, 0.48, (-1.00, 2.69, 1.36), mat_metal, workbench, rotation=(0.0, 0.0, math.radians(12)))
box("TaskLampHead", (0.30, 0.16, 0.08), (-0.94, 2.64, 1.60), mat_light, workbench, 0.035)

# Entry-side wardrobe, battery/power cabinet and survival storage.
add_cabinet("Wardrobe", (1.03, 1.83, 1.13), (0.56, 0.92, 1.78), mat_shell_dark, mat_cabinet, mat_metal, utilities, doors=2)
box("WardrobeVent", (0.035, 0.44, 0.30), (1.33, 1.83, 0.70), mat_black, utilities, 0.02)
add_cabinet("PowerCabinet", (-1.02, 1.16, 0.60), (0.58, 0.60, 0.90), mat_shell_dark, mat_shell, mat_metal, utilities, doors=1)
box("PowerPanel", (0.045, 0.43, 0.37), (-0.70, 1.16, 0.72), mat_black, utilities, 0.025)
for index, color_mat in enumerate([mat_cyan, mat_light, mat_red]):
    cylinder(f"PowerStatus_{index}", 0.025, 0.025, (-0.67, 1.00 + index * 0.15, 0.78), color_mat, utilities, rotation=(0.0, math.radians(90), 0.0), vertices=16, bevel=0.0)
box("BatteryGauge", (0.024, 0.26, 0.10), (-0.665, 1.18, 0.60), mat_screen, utilities, 0.012)
for index, y in enumerate([1.06, 1.48, 2.94]):
    crate = box(f"SurvivalCrate_{index + 1}", (0.54, 0.48, 0.38), (0.80 if index == 2 else -0.93, y, 0.38), mat_wood, utilities, 0.05)
    crate["ego_storage_units"] = 4
    box(f"SurvivalCrateBand_{index + 1}", (0.58, 0.08, 0.40), (crate.location.x, y, 0.38), mat_metal, utilities, 0.015)

# Lived-in clutter and identity, intentionally original and sparse at game start.
book_mats = [mat_blanket, mat_fabric, mat_paper, mat_accent]
for index in range(7):
    add_book(
        f"Book_{index + 1}",
        (1.02, -0.62 + index * 0.18, 1.91),
        (0.18, 0.055, 0.24 + (index % 3) * 0.025),
        book_mats[index % len(book_mats)],
        decor,
        rotation_z=(index % 2) * 0.06,
    )
box("RouteMapBoard", (0.08, 1.03, 0.72), (-1.31, -1.00, 1.58), mat_shell_dark, decor, 0.04)
box("RouteMapPaper", (0.035, 0.91, 0.61), (-1.35, -1.00, 1.58), mat_paper, decor, 0.025)
for index, (y, z) in enumerate([(-1.24, 1.70), (-1.04, 1.48), (-0.79, 1.64)]):
    box(f"MapRoute_{index}", (0.025, 0.32, 0.025), (-1.375, y, z), mat_red if index == 1 else mat_cyan, decor, 0.008, rotation=(0.0, 0.0, 0.16 * (index - 1)))
cylinder("PlantPot", 0.13, 0.20, (1.05, 0.67, 2.02), mat_wood, decor)
for index, angle in enumerate([-0.5, 0.0, 0.5]):
    sphere(f"PlantLeaf_{index}", (0.07, 0.18, 0.05), (1.05 + angle * 0.12, 0.67, 2.20), mat_green, decor)
box("MedicalCase", (0.46, 0.20, 0.34), (1.14, 2.60, 1.54), mat_shell, decor, 0.05)
box("MedicalCrossV", (0.025, 0.055, 0.20), (1.38, 2.60, 1.54), mat_red, decor, 0.01)
box("MedicalCrossH", (0.025, 0.18, 0.055), (1.38, 2.60, 1.54), mat_red, decor, 0.01)

# Walk-through right-hand-drive cockpit.  +Y is the vehicle's forward axis in
# Blender and becomes -Z after Godot's glTF axis conversion.
#
# The transparent glazing and perimeter-only roof structure are deliberate:
# this room is primarily read from a steep portrait camera, so the cabin must
# remain legible without hiding Hotaru below a dense roll-cage silhouette.
for x, side in [(-1.37, "L"), (1.37, "R")]:
    side_glass = box(
        f"CockpitSideWindow_{side}",
        (0.035, 1.78, 1.05),
        (x, 4.55, 1.58),
        mat_glass,
        cockpit,
        0.035,
    )
    side_glass["ego_toggle_for_cutaway"] = True
    box(f"CockpitA_Pillar_{side}", (0.15, 0.14, 1.56), (x, 5.48, 1.50), mat_shell_dark, cockpit, 0.035)
    box(f"CockpitB_Pillar_{side}", (0.14, 0.14, 1.56), (x, 3.60, 1.50), mat_shell_dark, cockpit, 0.035)
    box(f"CockpitDoorSill_{side}", (0.14, 1.82, 0.12), (x, 4.54, 0.88), mat_shell_dark, cockpit, 0.028)
    box(f"CockpitDoorHandle_{side}", (0.055, 0.28, 0.055), (x - (0.075 if x > 0 else -0.075), 4.28, 1.06), mat_metal, cockpit, 0.016)

# Aerodynamic nose, panoramic windscreen and sparse roof perimeter.
box("CockpitNoseLower", (2.72, 0.36, 0.66), (0.0, 5.70, 0.54), mat_shell, cockpit, 0.09)
windshield = box(
    "CockpitWindshield",
    (2.38, 0.045, 1.02),
    (0.0, 5.66, 1.70),
    mat_glass,
    cockpit,
    0.075,
    rotation=(math.radians(10.0), 0.0, 0.0),
)
windshield["ego_toggle_for_cutaway"] = True
box("CockpitWindshieldHeader", (2.58, 0.16, 0.16), (0.0, 5.56, 2.25), mat_shell_dark, cockpit, 0.035, rotation=(math.radians(10.0), 0.0, 0.0))
box("CockpitRoofConsole", (0.48, 0.70, 0.10), (0.0, 5.08, 2.29), mat_shell, cockpit, 0.04)
box("CockpitRoofDisplay", (0.26, 0.22, 0.035), (0.0, 4.78, 2.22), mat_screen, cockpit, 0.018, rotation=(math.radians(8.0), 0.0, 0.0))
for x in [-0.11, 0.0, 0.11]:
    cylinder("CockpitRoofStatus", 0.018, 0.026, (x, 5.18, 2.23), mat_indicator_green if x == 0.0 else mat_cyan, cockpit, vertices=16, bevel=0.0)

# Dashboard and controls.  The broad, low shape leaves the windscreen readable
# while retaining enough silhouette to make the new volume immediately "cab".
box("CockpitDashboardBody", (2.38, 0.58, 0.36), (0.0, 5.20, 0.94), mat_dash, cockpit, 0.055)
box("CockpitDashboardTop", (2.40, 0.67, 0.075), (0.0, 5.05, 1.13), mat_shell_dark, cockpit, 0.035, rotation=(math.radians(-4.0), 0.0, 0.0))
box("CockpitGloveBox", (0.76, 0.035, 0.24), (-0.70, 4.895, 0.91), mat_cabinet, cockpit, 0.025)
box("CockpitGloveBoxHandle", (0.22, 0.025, 0.035), (-0.70, 4.87, 0.98), mat_metal, cockpit, 0.010)

# Right-side driver instrument binnacle and two emissive analogue gauges.
box("CockpitInstrumentHood", (0.78, 0.24, 0.30), (0.67, 4.96, 1.25), mat_dash, cockpit, 0.045, rotation=(math.radians(-8.0), 0.0, 0.0))
box("CockpitInstrumentScreen", (0.54, 0.026, 0.19), (0.67, 4.82, 1.25), mat_screen, cockpit, 0.028, rotation=(math.radians(-8.0), 0.0, 0.0))
for x in [0.54, 0.80]:
    torus("CockpitGaugeRing", 0.077, 0.010, (x, 4.79, 1.27), mat_cyan, cockpit, rotation=(math.radians(90.0), 0.0, 0.0))
for index, x in enumerate([0.47, 0.58, 0.69, 0.80, 0.91]):
    cylinder(
        f"CockpitTellTale_{index + 1}",
        0.017,
        0.026,
        (x, 4.78, 1.15),
        mat_indicator_green if index in [0, 3] else mat_light,
        cockpit,
        rotation=(math.radians(90.0), 0.0, 0.0),
        vertices=16,
        bevel=0.0,
    )

# Steering column and wheel are also DriverSeat-prefixed so Godot can treat the
# entire driving station as one highlightable interactive module.
driver_parts = []
driver_parts.append(cylinder("DriverSeat_SteeringColumn", 0.040, 0.40, (0.70, 4.64, 1.04), mat_metal, cockpit, rotation=(math.radians(68.0), 0.0, 0.0)))
driver_parts.append(torus("DriverSeat_SteeringWheel", 0.205, 0.026, (0.70, 4.52, 1.22), mat_shell_dark, cockpit, rotation=(math.radians(72.0), 0.0, 0.0)))
for angle in [0.0, math.radians(120.0), math.radians(240.0)]:
    driver_parts.append(
        box(
            "DriverSeat_SteeringSpoke",
            (0.035, 0.19, 0.025),
            (0.70 + math.sin(angle) * 0.085, 4.52, 1.22 + math.cos(angle) * 0.085),
            mat_metal,
            cockpit,
            0.008,
            rotation=(math.radians(72.0), angle, 0.0),
        )
    )
driver_parts.append(cylinder("DriverSeat_SteeringHub", 0.070, 0.055, (0.70, 4.50, 1.21), mat_accent, cockpit, rotation=(math.radians(90.0), 0.0, 0.0), vertices=24))


def add_cockpit_seat(name, x, module_name):
    parts = []
    parts.append(box(f"{name}_Pedestal", (0.46, 0.46, 0.35), (x, 4.02, 0.39), mat_shell_dark, cockpit, 0.07))
    parts.append(box(f"{name}_Cushion", (0.63, 0.72, 0.17), (x, 4.04, 0.66), mat_seat, cockpit, 0.12))
    parts.append(box(f"{name}_Back", (0.62, 0.18, 0.78), (x, 3.72, 1.08), mat_seat, cockpit, 0.12, rotation=(math.radians(8.0), 0.0, 0.0)))
    parts.append(box(f"{name}_Headrest", (0.42, 0.16, 0.27), (x, 3.62, 1.58), mat_seat, cockpit, 0.09, rotation=(math.radians(8.0), 0.0, 0.0)))
    parts.append(box(f"{name}_OuterBolster", (0.12, 0.62, 0.20), (x + (0.27 if x > 0 else -0.27), 4.01, 0.77), mat_fabric, cockpit, 0.08))
    parts.append(box(f"{name}_InnerBolster", (0.12, 0.62, 0.20), (x - (0.27 if x > 0 else -0.27), 4.01, 0.77), mat_fabric, cockpit, 0.08))
    parts.append(box(f"{name}_SeatBelt", (0.055, 0.035, 0.72), (x + (0.20 if x > 0 else -0.20), 3.60, 1.17), mat_accent, cockpit, 0.012, rotation=(0.0, math.radians(13.0 if x > 0 else -13.0), 0.0)))
    for part in parts:
        part["ego_module"] = module_name
        part["ego_interactable"] = module_name == "DriverSeat"
    return parts


driver_parts.extend(add_cockpit_seat("DriverSeat", 0.72, "DriverSeat"))
add_cockpit_seat("PassengerSeat", -0.72, "PassengerSeat")
for part in driver_parts:
    part["ego_module"] = "DriverSeat"
    part["ego_interactable"] = True

# Low centre console keeps the aisle visually and physically continuous.
box("CockpitCenterConsole", (0.34, 0.82, 0.34), (0.0, 4.35, 0.40), mat_dash, cockpit, 0.07)
box("CockpitCenterTouchscreen", (0.27, 0.36, 0.035), (0.0, 4.40, 0.59), mat_screen, cockpit, 0.035, rotation=(math.radians(-8.0), 0.0, 0.0))
cylinder("CockpitGearLever", 0.030, 0.28, (0.0, 4.13, 0.72), mat_metal, cockpit, rotation=(math.radians(-12.0), 0.0, 0.0))
sphere("CockpitGearKnob", (0.065, 0.065, 0.075), (0.0, 4.10, 0.86), mat_shell_dark, cockpit)
for x, name in [(0.56, "Accelerator"), (0.86, "Brake")]:
    box(f"DriverSeat_{name}Pedal", (0.20, 0.28, 0.045), (x, 4.93, 0.30), mat_metal, cockpit, 0.025, rotation=(math.radians(-13.0), 0.0, 0.0))["ego_module"] = "DriverSeat"

# Small navigation tablet, demister slots and a rear-view monitor add the
# close-up detail expected from a long-lived home-base scene.
box("CockpitNavigationFrame", (0.42, 0.055, 0.30), (-0.03, 4.84, 1.25), mat_shell_dark, cockpit, 0.035, rotation=(math.radians(-8.0), 0.0, 0.0))
box("CockpitNavigationScreen", (0.35, 0.025, 0.23), (-0.03, 4.80, 1.25), mat_screen, cockpit, 0.025, rotation=(math.radians(-8.0), 0.0, 0.0))
for x in [-0.90, -0.45, 0.0, 0.45, 0.90]:
    box("CockpitDemisterSlot", (0.28, 0.08, 0.018), (x, 5.20, 1.185), mat_black, cockpit, 0.008)
box("CockpitRearViewMonitor", (0.40, 0.08, 0.18), (0.0, 5.32, 2.02), mat_shell_dark, cockpit, 0.035)
box("CockpitRearViewScreen", (0.32, 0.035, 0.11), (0.0, 5.27, 2.02), mat_screen, cockpit, 0.022)

# Upgrade-ready hardpoints are subtle but present from day one.
for name, location, slot_type, plate_size in [
    ("SOCKET_FLOOR_CENTER", (0.0, 1.45, 0.205), "floor_module", (0.70, 0.90, 0.018)),
    ("SOCKET_WALL_LEFT", (-1.355, 1.86, 1.72), "wall_module", (0.018, 0.62, 0.45)),
    ("SOCKET_WALL_RIGHT", (1.355, -1.72, 1.72), "wall_module", (0.018, 0.62, 0.45)),
    ("SOCKET_CEILING_REAR", (0.0, 2.60, 2.385), "ceiling_module", (0.80, 0.60, 0.018)),
]:
    plate = box(name + "_Plate", plate_size, location, mat_cyan, sockets, 0.018)
    plate["ego_slot_type"] = slot_type
    empty_socket(name, location, slot_type, sockets)

# Entry/exit marker consumed by the Godot wrapper.
entry = empty_socket("MARKER_ENTRY", (0.64, 2.92, 0.20), "entry", sockets)
entry["ego_facing_yaw_degrees"] = 180.0

# Driving interaction anchors.  Their positions are authored in Blender's
# Z-up coordinates; glTF converts +Y vehicle-forward to Godot -Z.
driver_seat_marker = empty_socket("MARKER_DRIVER_SEAT", (0.72, 4.04, 0.78), "driver_seat", sockets)
driver_seat_marker["ego_facing_yaw_degrees"] = 0.0
driver_seat_marker["ego_pose"] = "sit"
driver_stand_marker = empty_socket("MARKER_DRIVER_STAND", (0.0, 3.63, 0.20), "driver_stand", sockets)
driver_stand_marker["ego_facing_yaw_degrees"] = 0.0
driver_stand_marker["ego_pose"] = "stand"

# Gentle baked-in lights; Godot also adds a mobile-safe key light.
for index, location in enumerate([(-0.72, -1.4, 2.22), (0.72, 0.25, 2.22), (-0.55, 2.25, 2.18), (0.45, 4.55, 2.12)]):
    light_data = bpy.data.lights.new(f"InteriorLight_{index + 1}", type="POINT")
    light_data.energy = 65.0
    light_data.color = (1.0, 0.65, 0.36)
    light_data.shadow_soft_size = 1.2
    light = bpy.data.objects.new(f"InteriorLight_{index + 1}", light_data)
    light.location = location
    architecture.objects.link(light)

# Source file remains artist-editable; GLB is the engine deliverable.
bpy.context.scene["ego_asset_version"] = "rv_interior_initial_v2_cockpit"
bpy.context.scene["ego_scale_meters"] = 1.0
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
bpy.ops.export_scene.gltf(
    filepath=str(GLB_PATH),
    export_format="GLB",
    export_apply=True,
    # Runtime lights are authored in Godot so mobile exposure stays stable.
    export_lights=False,
    export_extras=True,
    export_yup=True,
)

# Portrait cutaway preview.
world = bpy.data.worlds.new("PreviewWorld")
bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.018, 0.023, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22

camera_data = bpy.data.cameras.new("PreviewCamera")
camera = bpy.data.objects.new("PreviewCamera", camera_data)
bpy.context.scene.collection.objects.link(camera)
bpy.context.scene.camera = camera
camera.location = (7.3, 11.2, 10.3)
camera.data.lens = 55
aim(camera, (0.0, 1.20, 1.0))

for name, location, energy, size, color in [
    ("PreviewKey", (3.8, 3.0, 7.2), 1100.0, 4.5, (1.0, 0.68, 0.40)),
    ("PreviewFill", (-4.2, 3.8, 4.8), 850.0, 4.5, (0.35, 0.63, 0.75)),
]:
    light_data = bpy.data.lights.new(name, type="AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size
    light_data.color = color
    light = bpy.data.objects.new(name, light_data)
    light.location = location
    aim(light, (0.0, 0.0, 0.8))
    bpy.context.scene.collection.objects.link(light)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(PREVIEW_PATH)
scene.render.film_transparent = False
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.look = "AgX - Medium High Contrast"
bpy.ops.render.render(write_still=True)

mesh_objects = [obj for obj in scene_root.all_objects if obj.type == "MESH"]
world_corners = [obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
bound_min = Vector((min(point.x for point in world_corners), min(point.y for point in world_corners), min(point.z for point in world_corners)))
bound_max = Vector((max(point.x for point in world_corners), max(point.y for point in world_corners), max(point.z for point in world_corners)))
bound_size = bound_max - bound_min
print(f"RV_INTERIOR_MESH_OBJECTS={len(mesh_objects)}")
print(f"RV_INTERIOR_POLYGONS={sum(len(obj.data.polygons) for obj in mesh_objects)}")
print(f"RV_INTERIOR_BOUNDS_MIN={bound_min.x:.3f},{bound_min.y:.3f},{bound_min.z:.3f}")
print(f"RV_INTERIOR_BOUNDS_MAX={bound_max.x:.3f},{bound_max.y:.3f},{bound_max.z:.3f}")
print(f"RV_INTERIOR_SIZE_METERS={bound_size.x:.3f},{bound_size.y:.3f},{bound_size.z:.3f}")
print("MARKER_DRIVER_SEAT=0.720,4.040,0.780")
print("MARKER_DRIVER_STAND=0.000,3.630,0.200")
print(f"RV_INTERIOR_GLB={GLB_PATH}")
print(f"RV_INTERIOR_BLEND={BLEND_PATH}")
print(f"RV_INTERIOR_PREVIEW={PREVIEW_PATH}")
