"""Convert the supplied static USDZ to a meter-scale GLB with cutaway groups.

Usage: python tools/convert_supermarket.py <source.usdz>
Requires usd-core, Pillow, numpy and fast-simplification. Original archive is read without modification.
"""
import io
import json
import math
import struct
import sys
import zipfile
from collections import defaultdict
from pathlib import Path

from PIL import Image
from pxr import Gf, Usd, UsdGeom, UsdShade
import numpy as np
import fast_simplification

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / 'Downloads/Supermarket.usdz'
OUT = ROOT / 'assets/third_party/supermarket'
OUT.mkdir(parents=True, exist_ok=True)
stage = Usd.Stage.Open(str(SOURCE))
unit = UsdGeom.GetStageMetersPerUnit(stage)
assert UsdGeom.GetStageUpAxis(stage) == 'Y', 'This conversion expects a Y-up asset'
archive = zipfile.ZipFile(SOURCE)
blob = bytearray()
gltf = dict(asset=dict(version='2.0', generator='Ego USDZ static converter'),
            scene=0, scenes=[dict(nodes=[])], nodes=[], meshes=[], materials=[],
            accessors=[], bufferViews=[], buffers=[], images=[], textures=[],
            samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)])


def view(data, target=None):
    while len(blob) % 4:
        blob.append(0)
    result = dict(buffer=0, byteOffset=len(blob), byteLength=len(data))
    if target:
        result['target'] = target
    blob.extend(data)
    gltf['bufferViews'].append(result)
    return len(gltf['bufferViews']) - 1


def accessor(values, width, kind, bounds=False):
    flat = [v for row in values for v in row]
    item = dict(bufferView=view(struct.pack('<' + 'f' * len(flat), *flat), 34962),
                componentType=5126, count=len(values), type=kind)
    if bounds:
        item['min'] = [min(row[i] for row in values) for i in range(width)]
        item['max'] = [max(row[i] for row in values) for i in range(width)]
    gltf['accessors'].append(item)
    return len(gltf['accessors']) - 1


material_ids = {}
texture_ids = {}
for prim in stage.Traverse():
    if not prim.IsA(UsdShade.Material):
        continue
    shader = next((UsdShade.Shader(p) for p in Usd.PrimRange(prim)
                   if p.IsA(UsdShade.Shader) and UsdShade.Shader(p).GetIdAttr().Get() == 'UsdPreviewSurface'), None)
    if not shader:
        continue
    color = shader.GetInput('diffuseColor').Get() or (1, 1, 1)
    opacity = shader.GetInput('opacity').Get()
    pbr = dict(baseColorFactor=[*map(float, color), float(opacity) if opacity is not None else 1.0],
               roughnessFactor=float(shader.GetInput('roughness').Get() or 0.6), metallicFactor=0)
    conn = shader.GetInput('diffuseColor').GetConnectedSource()
    if conn:
        tex_shader = UsdShade.Shader(conn[0].GetPrim())
        file = tex_shader.GetInput('file').Get()
        if file:
            name = file.path.lstrip('./')
            if name not in texture_ids:
                img = Image.open(io.BytesIO(archive.read(name))).convert('RGB')
                img.thumbnail((1024, 1024))
                buffer = io.BytesIO()
                img.save(buffer, format='JPEG', quality=88)
                gltf['images'].append(dict(bufferView=view(buffer.getvalue()), mimeType='image/jpeg'))
                gltf['textures'].append(dict(sampler=0, source=len(gltf['images']) - 1))
                texture_ids[name] = len(gltf['textures']) - 1
            pbr['baseColorTexture'] = dict(index=texture_ids[name])
    mat = dict(name=prim.GetName(), pbrMetallicRoughness=pbr, doubleSided=True)
    if pbr['baseColorFactor'][3] < 1:
        mat['alphaMode'] = 'BLEND'
    material_ids[str(prim.GetPath())] = len(gltf['materials'])
    gltf['materials'].append(mat)

cache = UsdGeom.XformCache()
groups = defaultdict(lambda: [[], [], []])
triangles = 0
for prim in stage.Traverse():
    if not prim.IsA(UsdGeom.Mesh):
        continue
    mesh = UsdGeom.Mesh(prim)
    transform = cache.GetLocalToWorldTransform(prim)
    source_points = np.asarray(mesh.GetPointsAttr().Get(), dtype=np.float64)
    matrix = np.asarray(transform)
    points = (source_points @ matrix[:3, :3] + matrix[3, :3]) * unit
    counts = mesh.GetFaceVertexCountsAttr().Get()
    indices = mesh.GetFaceVertexIndicesAttr().Get()
    uv = next((v for v in UsdGeom.PrimvarsAPI(prim).GetPrimvars()
               if str(v.GetName()).startswith('primvars:st')), None)
    uv_values = uv.ComputeFlattened() if uv else []
    interpolation = uv.GetInterpolation() if uv else ''
    binding = prim.GetRelationship('material:binding').GetTargets()
    mat_id = material_ids.get(str(binding[0]), 0) if binding else 0
    # Product bottles dominate the 1.35-million-face source. Reduce each
    # material independently, transferring UVs through the collapse map.
    if len(counts) > 4000 and all(c == 3 for c in counts):
        faces = np.array(indices, dtype=np.int32, copy=True).reshape(-1, 3)
        vertex_uv = np.zeros((len(points), 2), dtype=np.float32)
        if len(uv_values):
            if interpolation == 'vertex':
                vertex_uv[:] = np.asarray(uv_values)
            elif interpolation == 'faceVarying':
                vertex_uv[np.asarray(indices)] = np.asarray(uv_values)
        target = max(1200, int(len(faces) * 0.075))
        _, _, collapses = fast_simplification.simplify(points.copy(), faces.copy(), target_count=target, return_collapses=True)
        reduced, faces, mapping = fast_simplification.replay_simplification(points.copy(), faces.copy(), collapses)
        # Keep the closest original UV at each collapsed vertex. Material
        # boundaries are never collapsed together.
        distance = np.linalg.norm(points - reduced[mapping], axis=1)
        order = np.lexsort((distance, mapping))
        _, first = np.unique(mapping[order], return_index=True)
        uv_reduced = np.zeros((len(reduced), 2), dtype=np.float32)
        uv_reduced[mapping[order[first]]] = vertex_uv[order[first]]
        points = reduced
        indices = faces.reshape(-1)
        counts = np.full(len(faces), 3)
        uv_values = uv_reduced
        interpolation = 'vertex'
    handed = mesh.GetOrientationAttr().Get() == 'leftHanded'
    print('Converting', prim.GetParent().GetName(), len(counts), 'faces', flush=True)
    cursor = 0
    for face_index, count in enumerate(counts):
        corners = list(range(cursor, cursor + count))
        cursor += count
        for j in range(1, count - 1):
            cs = [corners[0], corners[j], corners[j + 1]]
            if handed:
                cs.reverse()
            ps = [points[indices[c]] for c in cs]
            # Keep low walls and furnishings. Split outer envelope by face so
            # the large combined wall mesh can still be used as a cutaway.
            category = 'Contents'
            if min(p[1] for p in ps) > 2.42:
                category = 'Roof'
            elif max(p[1] for p in ps) > 1.1:
                if min(p[0] for p in ps) > 3.70:
                    category = 'WallXP'
                elif max(p[0] for p in ps) < -3.70:
                    category = 'WallXN'
                elif min(p[2] for p in ps) > 3.12:
                    category = 'WallZP'
                elif max(p[2] for p in ps) < -3.50:
                    category = 'WallZN'
            a, b, c = [Gf.Vec3d(*map(float, p)) for p in ps]
            normal = Gf.Cross(b - a, c - a)
            if normal.GetLength() < 1e-10:
                continue
            normal.Normalize()
            dest = groups[(category, mat_id)]
            for corner, point in zip(cs, ps):
                dest[0].append(point)
                dest[1].append(tuple(normal))
                ui = corner if interpolation == 'faceVarying' else (face_index if interpolation == 'uniform' else (0 if interpolation == 'constant' else indices[corner]))
                st = uv_values[ui] if len(uv_values) else (0, 0)
                dest[2].append((float(st[0]), 1.0 - float(st[1])))
            triangles += 1

for (category, mat_id), (pos, normals, uvs) in sorted(groups.items()):
    name = category + '__' + gltf['materials'][mat_id]['name']
    primitive = dict(attributes=dict(POSITION=accessor(pos, 3, 'VEC3', True),
                                    NORMAL=accessor(normals, 3, 'VEC3'),
                                    TEXCOORD_0=accessor(uvs, 2, 'VEC2')), material=mat_id)
    gltf['meshes'].append(dict(name=name, primitives=[primitive]))
    gltf['nodes'].append(dict(name=name, mesh=len(gltf['meshes']) - 1))
    gltf['scenes'][0]['nodes'].append(len(gltf['nodes']) - 1)

gltf['buffers'] = [dict(byteLength=len(blob))]
encoded = json.dumps(gltf, default=float, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
blob += b'\0' * (-len(blob) % 4)
glb = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(encoded) + 8 + len(blob))
glb += struct.pack('<I4s', len(encoded), b'JSON') + encoded
glb += struct.pack('<I4s', len(blob), b'BIN\0') + blob
(OUT / 'supermarket.glb').write_bytes(glb)
report = dict(source=SOURCE.name, original_faces=1351876, triangles=triangles, meshes=len(groups),
              materials=len(gltf['materials']), textures=len(texture_ids), bytes=len(glb),
              meters_per_unit=unit, bounds_meters=[[-4.06, 0, -3.78], [4.06, 3, 3.78]])
(OUT / 'conversion.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))



