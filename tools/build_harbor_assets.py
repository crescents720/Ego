"""Build mobile-friendly harbor assets from the three user-supplied USDZ packs.

The source packs stay outside the repository.  This script extracts only the
water/shore textures, four representative containers, and the harbor crane.
The crane spreader is exported separately so gameplay can move it vertically.
"""

from __future__ import annotations

import io
import json
import os
import struct
import sys
import zipfile
from pathlib import Path

DEPS = Path(".codex-harbor-deps").resolve()
if DEPS.exists():
    sys.path.insert(0, str(DEPS))

import numpy as np
from PIL import Image
from pxr import Usd, UsdGeom, UsdShade


DOWNLOADS = Path(r"C:\Users\DingMeng\Downloads")
OUTPUT = Path("assets/harbor")
OUTPUT.mkdir(parents=True, exist_ok=True)


def _triangulate(mesh: UsdGeom.Mesh) -> np.ndarray:
    counts = np.asarray(mesh.GetFaceVertexCountsAttr().Get(), dtype=np.int64)
    indices = np.asarray(mesh.GetFaceVertexIndicesAttr().Get(), dtype=np.uint32)
    triangles: list[list[int]] = []
    offset = 0
    for count in counts:
        for corner in range(1, int(count) - 1):
            triangles.append([indices[offset], indices[offset + corner], indices[offset + corner + 1]])
        offset += int(count)
    result = np.asarray(triangles, dtype=np.uint32)
    if mesh.GetOrientationAttr().Get() == "leftHanded":
        result = result[:, ::-1]
    return result


def _uvs(prim: Usd.Prim, vertices: np.ndarray, triangles: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    candidates = [p for p in UsdGeom.PrimvarsAPI(prim).GetPrimvars() if "st" in str(p.GetName()).lower()]
    if not candidates:
        return vertices, np.zeros((len(vertices), 2), dtype=float), triangles
    values = np.asarray(candidates[0].ComputeFlattened(), dtype=float)
    if values.ndim != 2 or values.shape[1] < 2:
        return vertices, np.zeros((len(vertices), 2), dtype=float), triangles
    values = values[:, :2]
    values[:, 1] = 1.0 - values[:, 1]
    if len(values) == len(vertices):
        return vertices, values, triangles
    flattened = triangles.reshape(-1)
    if len(values) == len(flattened):
        expanded_vertices = vertices[flattened]
        expanded_triangles = np.arange(len(flattened), dtype=np.uint32).reshape(-1, 3)
        return expanded_vertices, values, expanded_triangles
    return vertices, np.zeros((len(vertices), 2), dtype=float), triangles


def _simplify(vertices: np.ndarray, uvs: np.ndarray, triangles: np.ndarray, reduction: float) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    if reduction <= 0.0 or len(triangles) < 5000:
        return vertices, uvs, triangles
    import fast_simplification

    source_vertices = vertices.copy()
    _, _, collapses = fast_simplification.simplify(
        (source_vertices - source_vertices.mean(axis=0)).copy(),
        triangles.copy(),
        target_reduction=reduction,
        return_collapses=True,
    )
    reduced_vertices, reduced_faces, mapping = fast_simplification.replay_simplification(
        source_vertices.copy(), triangles.copy(), collapses
    )
    del reduced_vertices
    count = int(np.max(mapping)) + 1
    positions = np.zeros((count, 3), dtype=float)
    texcoords = np.zeros((count, 2), dtype=float)
    weights = np.zeros(count, dtype=float)
    valid = mapping >= 0
    np.add.at(positions, mapping[valid], source_vertices[valid])
    np.add.at(texcoords, mapping[valid], uvs[valid])
    np.add.at(weights, mapping[valid], 1.0)
    positions /= np.maximum(weights[:, None], 1.0)
    texcoords /= np.maximum(weights[:, None], 1.0)
    return positions, texcoords, np.asarray(reduced_faces, dtype=np.uint32)


class GlbBuilder:
    def __init__(self, archive: zipfile.ZipFile, texture_limit: int = 1024):
        self.archive = archive
        self.texture_limit = texture_limit
        self.doc = {
            "asset": {"version": "2.0", "generator": "Ego harbor asset builder"},
            "scene": 0,
            "scenes": [{"nodes": []}],
            "nodes": [],
            "meshes": [],
            "materials": [],
            "images": [],
            "textures": [],
            "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
            "bufferViews": [],
            "accessors": [],
        }
        self.blob = bytearray()
        self.materials: dict[str, int] = {}
        self.triangles = 0

    def view(self, data: bytes) -> int:
        self.blob.extend(b"\0" * (-len(self.blob) % 4))
        offset = len(self.blob)
        self.blob.extend(data)
        self.doc["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(data)})
        return len(self.doc["bufferViews"]) - 1

    def accessor(self, values: np.ndarray, kind: str, integer: bool = False) -> int:
        array = np.asarray(values, dtype="<u4" if integer else "<f4")
        record = {
            "bufferView": self.view(array.tobytes()),
            "componentType": 5125 if integer else 5126,
            "count": int(len(array)),
            "type": kind,
        }
        if kind == "VEC3":
            record["min"] = array.min(axis=0).tolist()
            record["max"] = array.max(axis=0).tolist()
        self.doc["accessors"].append(record)
        return len(self.doc["accessors"]) - 1

    def material(self, material: UsdShade.Material) -> int:
        key = str(material.GetPath()) if material else "fallback"
        if key in self.materials:
            return self.materials[key]
        name = material.GetPrim().GetName() if material else "Fallback"
        pbr: dict = {"baseColorFactor": [0.48, 0.5, 0.48, 1.0], "metallicFactor": 0.05, "roughnessFactor": 0.72}
        alpha = False
        if material:
            for child in Usd.PrimRange(material.GetPrim()):
                if not child.IsA(UsdShade.Shader) or "tex_base" not in child.GetName().lower():
                    continue
                texture = UsdShade.Shader(child).GetInput("file").Get()
                if not texture:
                    continue
                image = Image.open(io.BytesIO(self.archive.read(texture.path))).convert("RGBA")
                image.thumbnail((self.texture_limit, self.texture_limit), Image.Resampling.LANCZOS)
                alpha = image.getextrema()[3][0] < 255
                output = io.BytesIO()
                image.save(output, "PNG", optimize=True)
                self.doc["images"].append({"bufferView": self.view(output.getvalue()), "mimeType": "image/png"})
                self.doc["textures"].append({"source": len(self.doc["images"]) - 1, "sampler": 0})
                pbr = {
                    "baseColorTexture": {"index": len(self.doc["textures"]) - 1},
                    "metallicFactor": 0.08,
                    "roughnessFactor": 0.68,
                }
                break
        self.materials[key] = len(self.doc["materials"])
        self.doc["materials"].append(
            {
                "name": name,
                "doubleSided": True,
                "alphaMode": "MASK" if alpha else "OPAQUE",
                "alphaCutoff": 0.45,
                "pbrMetallicRoughness": pbr,
            }
        )
        return self.materials[key]

    def add_mesh(self, name: str, vertices: np.ndarray, uvs: np.ndarray, triangles: np.ndarray, material: UsdShade.Material) -> None:
        normals = np.zeros_like(vertices)
        face_normals = np.cross(vertices[triangles[:, 1]] - vertices[triangles[:, 0]], vertices[triangles[:, 2]] - vertices[triangles[:, 0]])
        for corner in range(3):
            np.add.at(normals, triangles[:, corner], face_normals)
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-10)
        primitive = {
            "attributes": {
                "POSITION": self.accessor(vertices, "VEC3"),
                "NORMAL": self.accessor(normals, "VEC3"),
                "TEXCOORD_0": self.accessor(uvs, "VEC2"),
            },
            "indices": self.accessor(triangles.reshape(-1, 1), "SCALAR", True),
            "material": self.material(material),
        }
        self.doc["meshes"].append({"name": name, "primitives": [primitive]})
        self.doc["nodes"].append({"name": name, "mesh": len(self.doc["meshes"]) - 1})
        self.doc["scenes"][0]["nodes"].append(len(self.doc["nodes"]) - 1)
        self.triangles += len(triangles)

    def save(self, path: Path) -> int:
        self.doc["buffers"] = [{"byteLength": len(self.blob)}]
        encoded = json.dumps(self.doc, separators=(",", ":")).encode("utf-8")
        encoded += b" " * (-len(encoded) % 4)
        self.blob.extend(b"\0" * (-len(self.blob) % 4))
        data = (
            struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(self.blob))
            + struct.pack("<I4s", len(encoded), b"JSON")
            + encoded
            + struct.pack("<I4s", len(self.blob), b"BIN\0")
            + self.blob
        )
        path.write_bytes(data)
        return len(data)


def _world_vertices(prim: Usd.Prim, cache: UsdGeom.XformCache) -> np.ndarray:
    points = np.asarray(UsdGeom.Mesh(prim).GetPointsAttr().Get(), dtype=float)
    transform = np.asarray(cache.GetLocalToWorldTransform(prim), dtype=float)
    return points @ transform[:3, :3] + transform[3, :3]


def export_crane() -> dict:
    source = DOWNLOADS / "Harbor_crane.usdz"
    stage = Usd.Stage.Open(str(source))
    cache = UsdGeom.XformCache()
    archive = zipfile.ZipFile(source)
    parts = [(p, UsdGeom.Mesh(p), _world_vertices(p, cache)) for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)]
    body = [part for part in parts if "Crane_Spreader" not in str(part[0].GetPath())]
    all_body = np.concatenate([part[2] for part in body])
    base_origin = np.array([np.mean([all_body[:, 0].min(), all_body[:, 0].max()]), all_body[:, 1].min(), -150.0])
    scale = 0.01
    report = {"source": str(source), "scale": scale, "origin_cm": base_origin.tolist()}
    for output_name, selected, reduction in (("harbor_crane", body, 0.73), ("harbor_spreader", [p for p in parts if p not in body], 0.45)):
        builder = GlbBuilder(archive, 512)
        bounds = []
        for prim, mesh, vertices in selected:
            vertices = (vertices - base_origin) * scale
            triangles = _triangulate(mesh)
            vertices, uvs, triangles = _uvs(prim, vertices, triangles)
            vertices, uvs, triangles = _simplify(vertices, uvs, triangles, reduction)
            material = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()[0]
            builder.add_mesh(prim.GetName(), vertices, uvs, triangles, material)
            bounds.append(vertices)
        combined = np.concatenate(bounds)
        size = builder.save(OUTPUT / f"{output_name}.glb")
        report[output_name] = {
            "triangles": builder.triangles,
            "bytes": size,
            "bounds_min": combined.min(axis=0).tolist(),
            "bounds_max": combined.max(axis=0).tolist(),
        }
    return report


CONTAINERS = {
    "container_20_old": "Object_44",
    "container_20_blue": "Object_45",
    "container_20_red": "Object_46",
    "container_40_blue": "Object_36",
}


def export_containers() -> dict:
    source = DOWNLOADS / "Container_Pack.usdz"
    stage = Usd.Stage.Open(str(source))
    cache = UsdGeom.XformCache()
    archive = zipfile.ZipFile(source)
    by_name = {p.GetName(): p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)}
    report = {"source": str(source), "assets": {}}
    for output_name, prim_name in CONTAINERS.items():
        prim = by_name[prim_name]
        mesh = UsdGeom.Mesh(prim)
        vertices = _world_vertices(prim, cache)
        low, high = vertices.min(axis=0), vertices.max(axis=0)
        target_length = 12.19 if "_40_" in output_name else 6.06
        scale = target_length / (high[0] - low[0])
        origin = np.array([(low[0] + high[0]) * 0.5, low[1], (low[2] + high[2]) * 0.5])
        vertices = (vertices - origin) * scale
        triangles = _triangulate(mesh)
        vertices, uvs, triangles = _uvs(prim, vertices, triangles)
        # Container walls are thin corrugated sheets with face-varying UVs.
        # QEM reduction opens visible holes, so keep their already modest mesh.
        vertices, uvs, triangles = _simplify(vertices, uvs, triangles, 0.0)
        builder = GlbBuilder(archive, 512)
        material = UsdShade.MaterialBindingAPI(prim).ComputeBoundMaterial()[0]
        builder.add_mesh(output_name, vertices, uvs, triangles, material)
        size = builder.save(OUTPUT / f"{output_name}.glb")
        report["assets"][output_name] = {
            "triangles": builder.triangles,
            "bytes": size,
            "dimensions": np.ptp(vertices, axis=0).tolist(),
        }
    return report


def extract_terrain_textures() -> dict:
    source = DOWNLOADS / "gt_racing_2_-_weinberge.usdz"
    selected = {
        "0/Water_baseColor.jpg": "water_base.jpg",
        "0/Water_normal.jpg": "water_normal.jpg",
        "0/ROAD_Dirth_baseColor.jpg": "shore_dirt.jpg",
        "0/MOUNT_2_baseColor.jpg": "shore_rock.jpg",
    }
    report = {"source": str(source), "textures": {}}
    with zipfile.ZipFile(source) as archive:
        for member, output_name in selected.items():
            image = Image.open(io.BytesIO(archive.read(member))).convert("RGB")
            image.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
            image.save(OUTPUT / output_name, quality=88, optimize=True)
            report["textures"][output_name] = {"size": image.size, "bytes": (OUTPUT / output_name).stat().st_size}
    return report


def main() -> None:
    report = {
        "crane": export_crane(),
        "containers": export_containers(),
        "terrain": extract_terrain_textures(),
    }
    (OUTPUT / "asset_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
