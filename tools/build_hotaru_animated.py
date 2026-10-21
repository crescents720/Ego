"""Build a lightweight, skinned Hotaru character for Godot.

Run with Blender 4.2+ from the project root, for example:

    blender --background --python tools/build_hotaru_animated.py

The script intentionally reads the already-local ``girl.glb`` only.  It does
not copy the unlicensed source asset outside its existing character folder.
It produces:

* assets/characters/anime-girl/hotaru_animated.glb
* artifacts/hotaru_animated_preview.png

Coordinate contract of the exported asset:

* feet rest on local Y = 0 in Godot (Blender Z = 0 before glTF export)
* the face points toward local +Z in Godot (Blender -Y)
* no root motion; the Godot CharacterBody owns locomotion
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_GLB = PROJECT_ROOT / "assets" / "characters" / "anime-girl" / "girl.glb"
OUTPUT_GLB = PROJECT_ROOT / "assets" / "characters" / "anime-girl" / "hotaru_animated.glb"
PREVIEW_PNG = PROJECT_ROOT / "artifacts" / "hotaru_animated_preview.png"

FPS = 30


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def import_and_prepare_mesh() -> bpy.types.Object:
    if not SOURCE_GLB.exists():
        raise FileNotFoundError(f"Missing source character: {SOURCE_GLB}")

    bpy.ops.import_scene.gltf(filepath=str(SOURCE_GLB))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("girl.glb did not contain a mesh")

    # Join defensively so the rig continues to work if the source is later
    # split into several material meshes.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    mesh = bpy.context.active_object
    mesh.name = "HotaruMesh"
    mesh.data.name = "HotaruMeshData"

    # glTF import can defer its axis-conversion matrix until the next view
    # layer update.  Apply it before measuring; otherwise dimensions can be
    # read in world space while vertices are still in the source basis.
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # After glTF's deferred transform is applied, the mesh is Blender Z-up and
    # its face points toward -Y.  Centre it and place the soles on Z=0.
    # Blender -Y exports as Godot local +Z.
    vertices = [vertex.co for vertex in mesh.data.vertices]
    min_x = min(v.x for v in vertices)
    max_x = max(v.x for v in vertices)
    min_y = min(v.y for v in vertices)
    max_y = max(v.y for v in vertices)
    min_z = min(v.z for v in vertices)
    center_x = (min_x + max_x) * 0.5
    center_depth = (min_y + max_y) * 0.5

    # x' = x-center_x, y' = y-center_depth, z' = z-min_z
    orient = Matrix(
        (
            (1.0, 0.0, 0.0, -center_x),
            (0.0, 1.0, 0.0, -center_depth),
            (0.0, 0.0, 1.0, -min_z),
            (0.0, 0.0, 0.0, 1.0),
        )
    )
    mesh.data.transform(orient)
    mesh.data.update()
    bpy.context.view_layer.update()
    mesh.location = (0.0, 0.0, 0.0)
    mesh.rotation_euler = (0.0, 0.0, 0.0)
    mesh.scale = (1.0, 1.0, 1.0)

    for poly in mesh.data.polygons:
        poly.use_smooth = True

    return mesh


def add_bone(
    edit_bones,
    created: dict[str, bpy.types.EditBone],
    name: str,
    head: tuple[float, float, float],
    tail: tuple[float, float, float],
    parent: str | None = None,
    deform: bool = True,
    roll: float = 0.0,
) -> None:
    bone = edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.roll = roll
    bone.use_deform = deform
    if parent:
        bone.parent = created[parent]
    created[name] = bone


def build_armature() -> bpy.types.Object:
    arm_data = bpy.data.armatures.new("HotaruSkeleton")
    arm = bpy.data.objects.new("HotaruSkeleton", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    arm.show_in_front = True

    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    bones: dict[str, bpy.types.EditBone] = {}

    # Joint positions were measured against the supplied 1.55 m neutral pose.
    # Limbs are deliberately segmented, rather than assigning the whole mesh
    # to a single nearest bone, so feet, knees, elbows and wrists can articulate.
    add_bone(eb, bones, "Root", (0.0, 0.0, 0.00), (0.0, 0.0, 0.12), deform=False)
    add_bone(eb, bones, "Pelvis", (0.0, 0.005, 0.70), (0.0, 0.0, 0.81), "Root")
    add_bone(eb, bones, "Spine", (0.0, 0.0, 0.81), (0.0, -0.005, 1.02), "Pelvis")
    add_bone(eb, bones, "Chest", (0.0, -0.005, 1.02), (0.0, -0.005, 1.19), "Spine")
    add_bone(eb, bones, "Neck", (0.0, -0.005, 1.19), (0.0, -0.015, 1.31), "Chest")
    add_bone(eb, bones, "Head", (0.0, -0.015, 1.31), (0.0, -0.015, 1.51), "Neck")

    add_bone(eb, bones, "Clavicle.L", (-0.025, 0.0, 1.17), (-0.145, 0.0, 1.17), "Chest", deform=False)
    add_bone(eb, bones, "UpperArm.L", (-0.145, 0.0, 1.17), (-0.195, 0.0, 0.94), "Clavicle.L")
    add_bone(eb, bones, "Forearm.L", (-0.195, 0.0, 0.94), (-0.215, -0.005, 0.76), "UpperArm.L")
    add_bone(eb, bones, "Hand.L", (-0.215, -0.005, 0.76), (-0.215, -0.020, 0.68), "Forearm.L")

    add_bone(eb, bones, "Clavicle.R", (0.025, 0.0, 1.17), (0.145, 0.0, 1.17), "Chest", deform=False)
    add_bone(eb, bones, "UpperArm.R", (0.145, 0.0, 1.17), (0.195, 0.0, 0.94), "Clavicle.R")
    add_bone(eb, bones, "Forearm.R", (0.195, 0.0, 0.94), (0.215, -0.005, 0.76), "UpperArm.R")
    add_bone(eb, bones, "Hand.R", (0.215, -0.005, 0.76), (0.215, -0.020, 0.68), "Forearm.R")

    add_bone(eb, bones, "Thigh.L", (-0.085, 0.01, 0.73), (-0.090, 0.015, 0.42), "Pelvis")
    add_bone(eb, bones, "Shin.L", (-0.090, 0.015, 0.42), (-0.095, 0.01, 0.105), "Thigh.L")
    add_bone(eb, bones, "Foot.L", (-0.095, 0.01, 0.105), (-0.095, -0.125, 0.045), "Shin.L")
    add_bone(eb, bones, "Toe.L", (-0.095, -0.125, 0.045), (-0.095, -0.195, 0.035), "Foot.L")

    add_bone(eb, bones, "Thigh.R", (0.085, 0.01, 0.73), (0.090, 0.015, 0.42), "Pelvis")
    add_bone(eb, bones, "Shin.R", (0.090, 0.015, 0.42), (0.095, 0.01, 0.105), "Thigh.R")
    add_bone(eb, bones, "Foot.R", (0.095, 0.01, 0.105), (0.095, -0.125, 0.045), "Shin.R")
    add_bone(eb, bones, "Toe.R", (0.095, -0.125, 0.045), (0.095, -0.195, 0.035), "Foot.R")

    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind_mesh(mesh: bpy.types.Object, arm: bpy.types.Object) -> None:
    # Bone-heat weighting fails on this source because the body, hair and
    # clothing are disconnected shells.  Use deterministic anatomical regions
    # and distance-to-bone falloff instead.  This is smooth at joints, limited
    # to four weights per vertex, and produces identical results on every build.
    for group in list(mesh.vertex_groups):
        mesh.vertex_groups.remove(group)
    for modifier in list(mesh.modifiers):
        if modifier.type == "ARMATURE":
            mesh.modifiers.remove(modifier)

    deform_bones = {bone.name: bone for bone in arm.data.bones if bone.use_deform}
    groups = {name: mesh.vertex_groups.new(name=name) for name in deform_bones}

    # Record disconnected shells.  The garment hem overlaps the hands in X/Z,
    # so point-only classification would incorrectly pull the skirt with the
    # forearms.  Component bounds distinguish garments, limbs and accessories.
    adjacency: list[list[int]] = [[] for _ in mesh.data.vertices]
    for edge in mesh.data.edges:
        a, b = edge.vertices
        adjacency[a].append(b)
        adjacency[b].append(a)
    component_for_vertex: dict[int, dict[str, object]] = {}
    seen: set[int] = set()
    for start in range(len(mesh.data.vertices)):
        if start in seen:
            continue
        stack = [start]
        indices: list[int] = []
        seen.add(start)
        while stack:
            index = stack.pop()
            indices.append(index)
            for neighbour in adjacency[index]:
                if neighbour not in seen:
                    seen.add(neighbour)
                    stack.append(neighbour)
        points = [mesh.data.vertices[index].co for index in indices]
        component = {
            "count": len(indices),
            "min": Vector(tuple(min(point[axis] for point in points) for axis in range(3))),
            "max": Vector(tuple(max(point[axis] for point in points) for axis in range(3))),
            "center": sum(points, Vector()) / len(points),
        }
        for index in indices:
            component_for_vertex[index] = component

    def point_segment_distance(point: Vector, head: Vector, tail: Vector) -> float:
        segment = tail - head
        length_squared = segment.length_squared
        if length_squared < 1e-10:
            return (point - head).length
        t = max(0.0, min(1.0, (point - head).dot(segment) / length_squared))
        return (point - (head + segment * t)).length

    def side_name(base: str, x: float) -> str:
        return f"{base}.L" if x < 0.0 else f"{base}.R"

    def candidates(point: Vector, component: dict[str, object]) -> list[tuple[str, float]]:
        x_abs = abs(point.x)
        z = point.z
        side = ".L" if point.x < 0.0 else ".R"
        minimum: Vector = component["min"]
        maximum: Vector = component["max"]
        center: Vector = component["center"]
        size = maximum - minimum

        # Head, hair, eyes and face are separate shells but should travel as a
        # stable unit.  A tiny neck blend keeps the jaw transition soft.
        if minimum.z >= 1.24:
            return [("Head", 2.2), ("Neck", 0.9), ("Chest", 0.15)]

        # Shoes and long leg shells are easy to identify from ground contact.
        if maximum.z <= 0.14:
            return [("Foot" + side, 2.4), ("Toe" + side, 1.4), ("Shin" + side, 0.2)]
        if minimum.z < 0.18 and maximum.z > 0.32:
            return [
                ("Thigh" + side, 1.8),
                ("Shin" + side, 1.8),
                ("Foot" + side, 0.35),
                ("Pelvis", 0.12),
            ]

        # Wide shells around the hips are skirt/hoodie hems.  Bind them mostly
        # to the pelvis to preserve the silhouette instead of creating spikes
        # when the thighs oppose each other during Walk.
        is_hip_garment = (
            minimum.z >= 0.60
            and maximum.z <= 1.00
            and (size.x > 0.16 or abs(center.x) < 0.13)
        )
        if is_hip_garment:
            return [("Pelvis", 5.0), ("Spine", 0.25), ("Thigh.L", 0.08), ("Thigh.R", 0.08)]

        # The arm shells are narrow and tall; hands are compact shells farther
        # from the centreline.  Component classification prevents hem overlap.
        is_arm_shell = (
            minimum.z >= 0.72
            and maximum.z >= 1.02
            and size.x < 0.18
            and abs(center.x) > 0.09
        )
        is_hand_shell = (
            minimum.z >= 0.74
            and maximum.z <= 0.98
            and size.x < 0.10
            and abs(center.x) > 0.15
        )
        if is_hand_shell:
            return [("Hand" + side, 2.5), ("Forearm" + side, 0.9), ("UpperArm" + side, 0.08)]
        if is_arm_shell:
            return [("UpperArm" + side, 1.8), ("Forearm" + side, 1.6), ("Hand" + side, 0.2), ("Chest", 0.15)]

        if z >= 1.25:
            return [("Head", 2.2), ("Neck", 0.9), ("Chest", 0.15)]
        if z >= 1.12:
            if x_abs > 0.145:
                return [("UpperArm" + side, 2.2), ("Chest", 0.8), ("Neck", 0.25)]
            return [("Chest", 1.6), ("Neck", 1.1), ("Head", 0.35), ("Spine", 0.2)]
        if z >= 0.80:
            if x_abs > 0.155:
                return [
                    ("UpperArm" + side, 1.7),
                    ("Forearm" + side, 1.5),
                    ("Hand" + side, 0.25),
                    ("Chest", 0.3),
                ]
            return [("Chest", 1.0), ("Spine", 1.8), ("Pelvis", 0.35)]
        if z >= 0.64:
            if x_abs > 0.155:
                return [
                    ("Forearm" + side, 1.5),
                    ("Hand" + side, 1.8),
                    ("UpperArm" + side, 0.3),
                    ("Pelvis", 0.15),
                ]
            # The skirt bridges both thighs, so retain a symmetric influence
            # near the centre instead of tearing it down the middle.
            return [("Pelvis", 2.0), ("Thigh.L", 0.7), ("Thigh.R", 0.7), ("Spine", 0.2)]
        if z >= 0.12:
            primary = side_name("Thigh", point.x)
            lower = side_name("Shin", point.x)
            other = "Thigh.R" if primary.endswith(".L") else "Thigh.L"
            other_prior = 0.25 if x_abs < 0.055 and z > 0.55 else 0.02
            return [(primary, 1.7), (lower, 1.7), ("Pelvis", 0.25), (other, other_prior)]
        return [
            (side_name("Foot", point.x), 2.0),
            (side_name("Toe", point.x), 1.2),
            (side_name("Shin", point.x), 0.25),
        ]

    for vertex in mesh.data.vertices:
        weighted: list[tuple[str, float]] = []
        for bone_name, prior in candidates(vertex.co, component_for_vertex[vertex.index]):
            bone = deform_bones[bone_name]
            distance = point_segment_distance(vertex.co, bone.head_local, bone.tail_local)
            # A small floor prevents unweighted clothing corners while the
            # exponential falloff keeps the opposite limb from bleeding in.
            weight = prior * (math.exp(-((distance / 0.115) ** 2)) + 0.002)
            weighted.append((bone_name, weight))
        weighted.sort(key=lambda item: item[1], reverse=True)
        weighted = weighted[:4]
        total = sum(weight for _, weight in weighted)
        if total <= 1e-10:
            weighted = [("Pelvis", 1.0)]
            total = 1.0
        for bone_name, weight in weighted:
            groups[bone_name].add([vertex.index], weight / total, "REPLACE")

    mesh.parent = arm
    mesh.matrix_parent_inverse = arm.matrix_world.inverted()
    modifier = mesh.modifiers.new(name="HotaruArmature", type="ARMATURE")
    modifier.object = arm
    modifier.use_vertex_groups = True
    modifier.use_deform_preserve_volume = True

    if not mesh.vertex_groups or not any(mod.type == "ARMATURE" for mod in mesh.modifiers):
        raise RuntimeError("Deterministic armature binding failed")


def clear_pose(arm: bpy.types.Object) -> None:
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def key_pose(
    arm: bpy.types.Object,
    action: bpy.types.Action,
    frame: int,
    rotations: dict[str, tuple[float, float, float]] | None = None,
    locations: dict[str, tuple[float, float, float]] | None = None,
) -> None:
    arm.animation_data.action = action
    clear_pose(arm)
    rotations = rotations or {}
    locations = locations or {}
    for bone_name, degrees in rotations.items():
        pb = arm.pose.bones[bone_name]
        pb.rotation_euler = tuple(math.radians(value) for value in degrees)
    for bone_name, location in locations.items():
        arm.pose.bones[bone_name].location = location

    # Key every pose bone at each authored pose.  This makes each action fully
    # self-contained when Godot blends directly from another animation.
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_euler", frame=frame, group=pb.name)
        pb.keyframe_insert("location", frame=frame, group=pb.name)
        pb.keyframe_insert("scale", frame=frame, group=pb.name)


def set_interpolation(action: bpy.types.Action, mode: str) -> None:
    # Blender 5 stores curves in layered ActionChannelBags; Blender 4.2 and
    # earlier expose Action.fcurves directly.  Support both representations.
    fcurves = list(getattr(action, "fcurves", []))
    if not fcurves:
        for layer in action.layers:
            for strip in layer.strips:
                for channelbag in getattr(strip, "channelbags", []):
                    fcurves.extend(channelbag.fcurves)
    for fcurve in fcurves:
        for point in fcurve.keyframe_points:
            point.interpolation = mode


def make_actions(arm: bpy.types.Object) -> dict[str, bpy.types.Action]:
    arm.animation_data_create()
    actions: dict[str, bpy.types.Action] = {}

    idle = bpy.data.actions.new("Idle")
    idle.use_fake_user = True
    actions["Idle"] = idle
    key_pose(arm, idle, 1, {"Chest": (0, 0, -1.2), "UpperArm.L": (1.5, 0, 0), "UpperArm.R": (-1.5, 0, 0)})
    key_pose(
        arm,
        idle,
        31,
        {"Chest": (0.8, 0, 1.2), "Head": (-0.7, 0, -0.8), "UpperArm.L": (-1.0, 0, 0), "UpperArm.R": (1.0, 0, 0)},
        {"Pelvis": (0, 0.006, 0)},
    )
    key_pose(arm, idle, 61, {"Chest": (0, 0, -1.2), "UpperArm.L": (1.5, 0, 0), "UpperArm.R": (-1.5, 0, 0)})
    idle.frame_range = (1, 61)
    set_interpolation(idle, "BEZIER")

    walk = bpy.data.actions.new("Walk")
    walk.use_fake_user = True
    actions["Walk"] = walk

    # Four poses plus a duplicated first pose produce a clean 30-frame loop.
    # Arms are deliberately exaggerated slightly so they remain readable on a
    # phone screen at the game's isometric camera distance.
    contact_l = {
        "Pelvis": (0, 0, -3), "Chest": (0, 0, 4),
        "Thigh.L": (28, 0, 0), "Shin.L": (-6, 0, 0), "Foot.L": (-6, 0, 0),
        "Thigh.R": (-25, 0, 0), "Shin.R": (32, 0, 0), "Foot.R": (-10, 0, 0),
        "UpperArm.L": (-27, 0, 2), "Forearm.L": (-8, 0, 0),
        "UpperArm.R": (27, 0, -2), "Forearm.R": (-13, 0, 0),
    }
    passing_l = {
        "Pelvis": (0, 0, 2), "Chest": (-1, 0, 0),
        "Thigh.L": (4, 0, 0), "Shin.L": (7, 0, 0),
        "Thigh.R": (-2, 0, 0), "Shin.R": (12, 0, 0),
        "UpperArm.L": (-4, 0, 0), "UpperArm.R": (4, 0, 0),
    }
    contact_r = {name.replace(".L", ".TMP").replace(".R", ".L").replace(".TMP", ".R"): value for name, value in contact_l.items()}
    contact_r["Pelvis"] = (0, 0, 3)
    contact_r["Chest"] = (0, 0, -4)
    passing_r = {name.replace(".L", ".TMP").replace(".R", ".L").replace(".TMP", ".R"): value for name, value in passing_l.items()}
    passing_r["Pelvis"] = (0, 0, -2)

    key_pose(arm, walk, 1, contact_l, {"Pelvis": (0, 0.004, 0)})
    key_pose(arm, walk, 8, passing_l, {"Pelvis": (0, 0.020, 0)})
    key_pose(arm, walk, 16, contact_r, {"Pelvis": (0, 0.004, 0)})
    key_pose(arm, walk, 23, passing_r, {"Pelvis": (0, 0.020, 0)})
    key_pose(arm, walk, 31, contact_l, {"Pelvis": (0, 0.004, 0)})
    walk.frame_range = (1, 31)
    set_interpolation(walk, "BEZIER")

    sit = bpy.data.actions.new("Sit")
    sit.use_fake_user = True
    actions["Sit"] = sit
    sit_pose = {
        "Pelvis": (5, 0, 0), "Spine": (-5, 0, 0), "Chest": (-4, 0, 0),
        "Thigh.L": (78, 0, -2), "Thigh.R": (78, 0, 2),
        "Shin.L": (-78, 0, 0), "Shin.R": (-78, 0, 0),
        "Foot.L": (7, 0, 0), "Foot.R": (7, 0, 0),
        "UpperArm.L": (18, 0, -7), "UpperArm.R": (18, 0, 7),
        "Forearm.L": (-38, 0, 0), "Forearm.R": (-38, 0, 0),
        "Head": (4, 0, 0),
    }
    # Pelvis local Y follows the vertical bone, so -0.29 lowers the hips while
    # keeping the character root itself at floor level for easy seat snapping.
    key_pose(arm, sit, 1, sit_pose, {"Pelvis": (0, -0.29, 0.03)})
    key_pose(arm, sit, 60, sit_pose, {"Pelvis": (0, -0.29, 0.03)})
    sit.frame_range = (1, 60)
    set_interpolation(sit, "LINEAR")

    arm.animation_data.action = idle
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 61
    bpy.context.scene.render.fps = FPS
    return actions


def export_character(mesh: bpy.types.Object, arm: bpy.types.Object) -> None:
    OUTPUT_GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm

    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_slide_to_zero=True,
        export_optimize_animation_size=False,
        export_skins=True,
        export_yup=True,
    )


def look_at(obj: bpy.types.Object, point: Vector) -> None:
    obj.rotation_euler = (point - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_preview(
    arm: bpy.types.Object,
    actions: dict[str, bpy.types.Action],
    action_name: str = "Walk",
    output_path: Path = PREVIEW_PNG,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    arm.animation_data.action = actions[action_name]
    bpy.context.scene.frame_set(1)

    # A clean studio card makes silhouette and ground contact easy to inspect.
    bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0.0, 0.0, -0.006))
    floor = bpy.context.active_object
    floor.name = "PreviewFloor"
    floor_mat = bpy.data.materials.new("PreviewFloorMaterial")
    floor_mat.diffuse_color = (0.08, 0.11, 0.15, 1.0)
    floor.data.materials.append(floor_mat)

    bpy.ops.object.camera_add(location=(2.25, -3.35, 1.35))
    camera = bpy.context.active_object
    camera.name = "PreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.95
    look_at(camera, Vector((0.0, 0.0, 0.80)))
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(-1.7, -2.8, 3.4))
    key = bpy.context.active_object
    key.data.energy = 900
    key.data.shape = "DISK"
    key.data.size = 2.2
    look_at(key, Vector((0.0, 0.0, 0.9)))

    bpy.ops.object.light_add(type="AREA", location=(2.0, 1.2, 2.0))
    fill = bpy.context.active_object
    fill.data.energy = 550
    fill.data.size = 2.0
    look_at(fill, Vector((0.0, 0.0, 0.9)))

    bpy.ops.object.light_add(type="AREA", location=(-1.0, 1.2, 1.4))
    rim = bpy.context.active_object
    rim.data.energy = 650
    rim.data.color = (0.3, 0.75, 1.0)
    rim.data.size = 1.3
    look_at(rim, Vector((0.0, 0.0, 1.0)))

    world = bpy.context.scene.world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (0.025, 0.035, 0.055, 1.0)
    background.inputs[1].default_value = 0.45

    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(output_path)
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


def world_bbox(mesh: bpy.types.Object) -> tuple[Vector, Vector]:
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    corners = [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    minimum = Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners)))
    maximum = Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners)))
    return minimum, maximum


def main() -> None:
    clear_scene()
    mesh = import_and_prepare_mesh()
    arm = build_armature()
    bind_mesh(mesh, arm)
    actions = make_actions(arm)

    arm.animation_data.action = actions["Idle"]
    bpy.context.scene.frame_set(1)
    min_corner, max_corner = world_bbox(mesh)
    dims = max_corner - min_corner

    export_character(mesh, arm)
    render_preview(arm, actions)

    print("HOTARU_BUILD_OK")
    print(f"OUTPUT={OUTPUT_GLB}")
    print(f"PREVIEW={PREVIEW_PNG}")
    print(f"ANIMATIONS={','.join(actions.keys())}")
    print(
        "REST_BOUNDS_BLENDER="
        f"min({min_corner.x:.4f},{min_corner.y:.4f},{min_corner.z:.4f}) "
        f"max({max_corner.x:.4f},{max_corner.y:.4f},{max_corner.z:.4f}) "
        f"size({dims.x:.4f},{dims.y:.4f},{dims.z:.4f})"
    )
    print("FACING=Blender -Y / Godot local +Z")


if __name__ == "__main__":
    main()
