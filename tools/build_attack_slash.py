"""Extract the blue slash supplied in Attack_slashes.usdz as a mobile GLB.

The source contains six separated effect variants.  This converter selects the
mesh bound to the material named ``slash``, recentres its curved surface in a
stable PCA frame and combines the USD emissive JPEG with its separate alpha PNG.
The original archive is read-only and is never modified.
"""

from __future__ import annotations

import io
import json
import struct
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCAL_USD = ROOT / ".codex-usd-deps"
if LOCAL_USD.exists():
    sys.path.insert(0, str(LOCAL_USD))

import numpy as np
from PIL import Image
from pxr import Usd, UsdGeom, UsdShade


SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Downloads" / "Attack_slashes.usdz"
OUTPUT = ROOT / "assets" / "temple" / "blue_slash.glb"
REPORT = ROOT / "assets" / "temple" / "blue_slash.json"


def buffer_view(document: dict, blob: bytearray, data: bytes, target: int | None = None) -> int:
    blob.extend(b"\0" * (-len(blob) % 4))
    offset = len(blob)
    blob.extend(data)
    result = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
    if target is not None:
        result["target"] = target
    document["bufferViews"].append(result)
    return len(document["bufferViews"]) - 1


def accessor(document: dict, blob: bytearray, values: np.ndarray, kind: str, component: int, target: int) -> int:
    values = np.ascontiguousarray(values)
    result = {
        "bufferView": buffer_view(document, blob, values.tobytes(), target),
        "componentType": component,
        "count": len(values),
        "type": kind,
    }
    if kind == "VEC3":
        result["min"] = values.min(axis=0).tolist()
        result["max"] = values.max(axis=0).tolist()
    document["accessors"].append(result)
    return len(document["accessors"]) - 1


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(SOURCE)
    stage = Usd.Stage.Open(str(SOURCE))
    cache = UsdGeom.XformCache()
    source_mesh = None
    source_material = None
    for prim in stage.Traverse():
        if not prim.IsA(UsdGeom.Mesh):
            continue
        material = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()[0]
        if material and material.GetPrim().GetName() == "slash":
            source_mesh = UsdGeom.Mesh(prim)
            source_material = material
            break
    if source_mesh is None or source_material is None:
        raise RuntimeError("The blue 'slash' material mesh was not found")

    points = np.asarray(source_mesh.GetPointsAttr().Get(), dtype=np.float64)
    world = np.asarray(cache.GetLocalToWorldTransform(source_mesh.GetPrim()), dtype=np.float64)
    points = points @ world[:3, :3] + world[3, :3]
    centre = (points.min(axis=0) + points.max(axis=0)) * 0.5
    eigenvalues, eigenvectors = np.linalg.eigh(np.cov((points - centre).T))
    major = eigenvectors[:, int(np.argmax(eigenvalues))]
    normal = eigenvectors[:, int(np.argmin(eigenvalues))]
    minor = np.cross(normal, major)
    minor /= np.linalg.norm(minor)
    normal = np.cross(major, minor)
    frame = np.column_stack((major, minor, normal))
    points = (points - centre) @ frame
    points -= (points.min(axis=0) + points.max(axis=0)) * 0.5
    points *= 2.15 / np.ptp(points, axis=0).max()
    points = points.astype("<f4")

    counts = np.asarray(source_mesh.GetFaceVertexCountsAttr().Get(), dtype=np.int32)
    face_vertices = np.asarray(source_mesh.GetFaceVertexIndicesAttr().Get(), dtype=np.uint32)
    triangles: list[list[int]] = []
    cursor = 0
    for count in counts:
        for corner in range(1, int(count) - 1):
            triangles.append([int(face_vertices[cursor]), int(face_vertices[cursor + corner]), int(face_vertices[cursor + corner + 1])])
        cursor += int(count)
    indices = np.asarray(triangles, dtype="<u4")
    if source_mesh.GetOrientationAttr().Get() == "leftHanded":
        indices = indices[:, ::-1].copy()

    uv_primvar = next(primvar for primvar in UsdGeom.PrimvarsAPI(source_mesh).GetPrimvars() if str(primvar.GetName()) == "primvars:st0")
    uvs = np.array(uv_primvar.ComputeFlattened(), dtype="<f4", copy=True)
    if len(uvs) != len(points):
        raise RuntimeError(f"Unexpected UV count {len(uvs)} for {len(points)} vertices")
    uvs[:, 1] = 1.0 - uvs[:, 1]

    emissive_path = None
    opacity_path = None
    for prim in Usd.PrimRange(source_material.GetPrim()):
        if not prim.IsA(UsdShade.Shader):
            continue
        shader = UsdShade.Shader(prim)
        file_input = shader.GetInput("file")
        asset = file_input.Get() if file_input else None
        if not asset:
            continue
        if "emissive" in prim.GetName():
            emissive_path = asset.path
        elif "opacity" in prim.GetName():
            opacity_path = asset.path
    if not emissive_path or not opacity_path:
        raise RuntimeError("Blue slash emissive/opacity textures were not found")
    with zipfile.ZipFile(SOURCE) as archive:
        rgb = Image.open(io.BytesIO(archive.read(emissive_path))).convert("RGB")
        alpha = Image.open(io.BytesIO(archive.read(opacity_path))).convert("RGBA").getchannel("A")
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha)
    texture_bytes = io.BytesIO()
    rgba.save(texture_bytes, "PNG", optimize=True)

    document = {
        "asset": {"version": "2.0", "generator": "Ego build_attack_slash.py"},
        "extensionsUsed": ["KHR_materials_unlit"],
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "BlueSlash", "mesh": 0}],
        "meshes": [{"name": "BlueSlash", "primitives": []}],
        "materials": [{
            "name": "BlueSlashUnlit",
            "doubleSided": True,
            "alphaMode": "BLEND",
            "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "roughnessFactor": 1.0},
            "emissiveTexture": {"index": 0},
            "emissiveFactor": [1.0, 1.0, 1.0],
            "extensions": {"KHR_materials_unlit": {}},
        }],
        "images": [],
        "textures": [{"source": 0}],
        "bufferViews": [],
        "accessors": [],
    }
    blob = bytearray()
    document["images"].append({"bufferView": buffer_view(document, blob, texture_bytes.getvalue()), "mimeType": "image/png"})
    position_accessor = accessor(document, blob, points, "VEC3", 5126, 34962)
    uv_accessor = accessor(document, blob, uvs, "VEC2", 5126, 34962)
    index_accessor = accessor(document, blob, indices.reshape(-1), "SCALAR", 5125, 34963)
    document["meshes"][0]["primitives"].append({
        "attributes": {"POSITION": position_accessor, "TEXCOORD_0": uv_accessor},
        "indices": index_accessor,
        "material": 0,
    })
    document["buffers"] = [{"byteLength": len(blob)}]
    encoded = json.dumps(document, separators=(",", ":")).encode("utf-8")
    encoded += b" " * (-len(encoded) % 4)
    blob.extend(b"\0" * (-len(blob) % 4))
    payload = (
        struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(blob))
        + struct.pack("<I4s", len(encoded), b"JSON")
        + encoded
        + struct.pack("<I4s", len(blob), b"BIN\0")
        + blob
    )
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(payload)
    REPORT.write_text(json.dumps({
        "source": SOURCE.name,
        "variant": "slash",
        "vertices": len(points),
        "triangles": len(indices),
        "dimensions_m": np.ptp(points, axis=0).round(6).tolist(),
        "bytes": len(payload),
        "source_unchanged": True,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(REPORT.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
