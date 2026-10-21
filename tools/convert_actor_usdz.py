"""Convert user-supplied RV and zombie USDZ assets into meter-scale game GLBs.

Requires usd-core, numpy, Pillow, fast-simplification. No source files changed.
RV faces local -Z, right side +X. Zombie faces +Z, soles at Y=0.
"""
import io
import json
import math
import struct
import zipfile
from collections import defaultdict
from pathlib import Path
import numpy as np
import fast_simplification
from PIL import Image
from pxr import Usd, UsdGeom, UsdShade

ROOT = Path(__file__).resolve().parents[1]


def convert(filename, folder, output, rv=False, scene="", root_filter="", scale_multiplier=1.0):
    source = Path.home() / 'Downloads' / filename
    stage = Usd.Stage.Open(str(source))
    unit = UsdGeom.GetStageMetersPerUnit(stage) * scale_multiplier
    archive = zipfile.ZipFile(source)
    cache = UsdGeom.XformCache()
    meshes = []
    for prim in stage.Traverse():
        if prim.IsA(UsdGeom.Mesh):
            if root_filter and ('/RootNode/' + root_filter + '/') not in str(prim.GetPath()):
                continue
            mesh = UsdGeom.Mesh(prim)
            matrix = np.array(cache.GetLocalToWorldTransform(prim))
            points = np.array(mesh.GetPointsAttr().Get(), dtype=float)
            points = (points @ matrix[:3, :3] + matrix[3, :3]) * unit
            meshes.append((prim, mesh, matrix, points))
    # Undo the small presentation yaw on the supplied vehicle; rotate its
    # front (+Z) to the controller's -Z without mirroring the side door.
    angle = math.pi + math.atan2(0.0005693283746950328, 0.006224015261977911) if rv else 0
    rotation = np.array([[math.cos(angle), 0, math.sin(angle)], [0, 1, 0], [-math.sin(angle), 0, math.cos(angle)]])
    all_points = np.concatenate([m[3] @ rotation.T for m in meshes])
    minimum, maximum = all_points.min(axis=0), all_points.max(axis=0)
    center = (minimum + maximum) / 2
    center[1] = minimum[1]
    # Center the zombie on its hips, not the midpoint of its reaching hands.
    if not rv and not scene:
        boots = next(m[3] for m in meshes if 'Boots' in str(m[0].GetPath()))
        center[[0, 2]] = (boots.min(axis=0)[[0, 2]] + boots.max(axis=0)[[0, 2]]) / 2
    blob = bytearray()
    g = dict(asset=dict(version='2.0', generator='Ego actor USDZ converter'), scene=0,
        scenes=[dict(nodes=[])], nodes=[], meshes=[], materials=[], accessors=[], bufferViews=[],
        images=[], textures=[], samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)], buffers=[])

    def view(data, target=None):
        blob.extend(b'\0' * (-len(blob) % 4))
        v = dict(buffer=0, byteOffset=len(blob), byteLength=len(data))
        if target:
            v['target'] = target
        blob.extend(data)
        g['bufferViews'].append(v)
        return len(g['bufferViews']) - 1

    def accessor(data, kind, bounds=False):
        a = np.asarray(data, dtype='<f4')
        item = dict(bufferView=view(a.tobytes(), 34962), componentType=5126, count=len(a), type=kind)
        if bounds:
            item.update(min=a.min(axis=0).tolist(), max=a.max(axis=0).tolist())
        g['accessors'].append(item)
        return len(g['accessors']) - 1

    mat_ids = {}
    texture_ids = {}
    used_materials = {str(t) for prim, _, _, _ in meshes for t in prim.GetRelationship('material:binding').GetTargets()}
    for prim in stage.Traverse():
        if not prim.IsA(UsdShade.Material):
            continue
        if root_filter and str(prim.GetPath()) not in used_materials:
            continue
        shader = next((UsdShade.Shader(p) for p in Usd.PrimRange(prim)
                       if p.IsA(UsdShade.Shader) and UsdShade.Shader(p).GetIdAttr().Get() == 'UsdPreviewSurface'), None)
        if not shader:
            continue
        color = shader.GetInput('diffuseColor').Get() or (1, 1, 1)
        pbr = dict(baseColorFactor=[*map(float, color), 1], metallicFactor=0, roughnessFactor=0.85)
        conn = shader.GetInput('diffuseColor').GetConnectedSource()
        if conn:
            file = UsdShade.Shader(conn[0].GetPrim()).GetInput('file').Get()
            if file:
                name = file.path.lstrip('./')
                if name not in texture_ids:
                    image = Image.open(io.BytesIO(archive.read(name))).convert('RGB')
                    image.thumbnail((1024, 1024))
                    buf = io.BytesIO()
                    image.save(buf, 'JPEG', quality=90)
                    g['images'].append(dict(bufferView=view(buf.getvalue()), mimeType='image/jpeg'))
                    g['textures'].append(dict(source=len(g['images']) - 1, sampler=0))
                    texture_ids[name] = len(g['textures']) - 1
                pbr['baseColorTexture'] = dict(index=texture_ids[name])
        key = json.dumps(pbr, sort_keys=True)
        existing = next((i for i, m in enumerate(g['materials']) if m.get('extras', {}).get('key') == key), None)
        if existing is None:
            existing = len(g['materials'])
            g['materials'].append(dict(name=prim.GetName(), doubleSided=True,
                                      pbrMetallicRoughness=pbr, extras=dict(key=key)))
        mat_ids[str(prim.GetPath())] = existing
    groups = defaultdict(lambda: [[], [], []])
    original_triangles = 0
    for prim, mesh, matrix, raw_points in meshes:
        points = raw_points @ rotation.T - center
        counts = list(mesh.GetFaceVertexCountsAttr().Get())
        indices = np.array(mesh.GetFaceVertexIndicesAttr().Get(), dtype=np.int32)
        corners, faces = [], []
        cursor = 0
        for count in counts:
            for j in range(1, count - 1):
                corners.append([cursor, cursor+j, cursor+j+1])
                faces.append(indices[[cursor, cursor+j, cursor+j+1]])
            cursor += count
        faces = np.array(faces, dtype=np.int32)
        corners = np.array(corners, dtype=np.int32)
        if mesh.GetOrientationAttr().Get() == 'leftHanded':
            faces = faces[:, ::-1].copy()
            corners = corners[:, ::-1].copy()
        uv = next((v for v in UsdGeom.PrimvarsAPI(prim).GetPrimvars() if str(v.GetName()).startswith('primvars:st')), None)
        values = np.array(uv.ComputeFlattened(), dtype=float) if uv else np.zeros((len(points), 2))
        vertex_uv = np.zeros((len(points), 2))
        if uv and uv.GetInterpolation() == 'faceVarying':
            vertex_uv[indices] = values
        elif len(values) == len(points):
            vertex_uv[:] = values
        original_triangles += len(faces)
        if scene == 'bedroom':
            # CAD export duplicates vertices at virtually every face. Weld
            # positions before decimation; keep representative UVs per point.
            _, first, mapping = np.unique(np.round(points, 5), axis=0, return_index=True, return_inverse=True)
            points = points[first]
            vertex_uv = vertex_uv[first]
            faces = mapping[faces].astype(np.int32)
            faces = faces[(faces[:,0] != faces[:,1]) & (faces[:,1] != faces[:,2]) & (faces[:,0] != faces[:,2])]
            area = np.linalg.norm(np.cross(points[faces[:,1]]-points[faces[:,0]], points[faces[:,2]]-points[faces[:,0]]),axis=1)
            faces = faces[area > 1e-8]
            _, unique_faces = np.unique(np.sort(faces,axis=1),axis=0,return_index=True)
            faces = faces[unique_faces]
            if len(faces) == 0:
                continue
        if (rv and len(faces) > 2500) or (scene == "bedroom" and len(faces) > 600):
            target = max(120, min(2200, int(len(faces) * 0.015))) if scene == "bedroom" else max(600, int(len(faces) * 0.18))
            _, _, collapses = fast_simplification.simplify(points.copy(), faces.copy(), target_count=target, return_collapses=True)
            reduced, faces, mapping = fast_simplification.replay_simplification(points.copy(), faces.copy(), collapses)
            distance = np.linalg.norm(points - reduced[mapping], axis=1)
            order = np.lexsort((distance, mapping))
            _, first = np.unique(mapping[order], return_index=True)
            new_uv = np.zeros((len(reduced), 2))
            new_uv[mapping[order[first]]] = vertex_uv[order[first]]
            points, vertex_uv = reduced, new_uv
        if scene == "bedroom":
            print(prim.GetParent().GetName(), len(faces), flush=True)
        pos = points[faces]
        valid = np.isfinite(pos).all(axis=(1,2))
        faces = faces[valid]
        pos = pos[valid]
        if len(faces) == 0:
            continue
        normals = np.cross(pos[:, 1] - pos[:, 0], pos[:, 2] - pos[:, 0])
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-12)
        binding = prim.GetRelationship('material:binding').GetTargets()
        mat_id = mat_ids[str(binding[0])]
        uv_faces = vertex_uv[faces].copy()
        if scene == 'town' and uv and uv.GetInterpolation() == 'faceVarying':
            uv_faces = values[corners].copy()[valid]
        uv_faces[:, :, 1] = 1 - uv_faces[:, :, 1]
        categories = np.where(pos[:, :, 1].max(axis=1) > 2.35, 'Shell', 'Contents') if scene == 'bedroom' else np.full(len(faces), 'Model')
        for category in np.unique(categories):
            mask = categories == category
            dest = groups[(str(category), mat_id)]
            dest[0].extend(pos[mask].reshape(-1, 3))
            dest[1].extend(np.repeat(normals[mask], 3, axis=0))
            dest[2].extend(uv_faces[mask].reshape(-1, 2))
    triangles = 0
    for (category, mat_id), (pos, normals, uv) in groups.items():
        attributes = dict(POSITION=accessor(pos, 'VEC3', True), NORMAL=accessor(normals, 'VEC3'), TEXCOORD_0=accessor(uv, 'VEC2'))
        name = category + '__' + g['materials'][mat_id]['name']
        g['meshes'].append(dict(name=name, primitives=[dict(attributes=attributes, material=mat_id)]))
        g['nodes'].append(dict(name=name, mesh=len(g['meshes']) - 1))
        g['scenes'][0]['nodes'].append(len(g['nodes']) - 1)
        triangles += len(pos) // 3
    for m in g['materials']:
        m.pop('extras', None)
    g['buffers'] = [dict(byteLength=len(blob))]
    encoded = json.dumps(g, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    blob.extend(b'\0' * (-len(blob) % 4))
    result = struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(blob))
    result += struct.pack('<I4s', len(encoded), b'JSON') + encoded
    result += struct.pack('<I4s', len(blob), b'BIN\0') + blob
    folder = ROOT / folder
    folder.mkdir(parents=True, exist_ok=True)
    (folder / output).write_bytes(result)
    report = dict(source=filename, original_triangles=original_triangles, triangles=triangles,
                  materials=len(g['materials']), textures=len(g['textures']), bytes=len(result),
                  bounds_min=(minimum-center).tolist(), bounds_max=(maximum-center).tolist(),
                  bones=0, animations=0)
    (folder / (output + '.json')).write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    convert('Breaking_Bad_1986_Fleetwood_Bounder_RV.usdz', 'assets/vehicles/bounder', 'bounder.glb', True)
    convert('Zombie.usdz', 'assets/characters/zombie', 'zombie.glb')

