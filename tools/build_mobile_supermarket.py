"""Build the runtime shop from the USDZ conversion, replacing tiny products.

Run after convert_supermarket.py. Requires pygltflib, numpy and Pillow.
Keeps architecture and shelving, batches plain colors, and uses a single
1024px atlas for low-poly product cases. The reference conversion is intact.
"""
import copy
import io
import json
import struct
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image
from pygltflib import GLTF2

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/third_party/supermarket'
source = GLTF2().load(str(OUT / 'supermarket.glb'))
source_blob = source.binary_blob()
blob = bytearray()
g = dict(asset=dict(version='2.0', generator='Ego mobile shelf batching'), scene=0,
         scenes=[dict(nodes=[])], nodes=[], meshes=[], materials=[], accessors=[],
         bufferViews=[], images=[], textures=[], samplers=[dict(magFilter=9729, minFilter=9987)], buffers=[])


def view(data, target=None):
    blob.extend(b'\0' * (-len(blob) % 4))
    item = dict(buffer=0, byteOffset=len(blob), byteLength=len(data))
    if target:
        item['target'] = target
    blob.extend(data)
    g['bufferViews'].append(item)
    return len(g['bufferViews']) - 1


def accessor(values, kind, bounds=False):
    a = np.asarray(values, dtype='<f4')
    item = dict(bufferView=view(a.tobytes(), 34962), componentType=5126, count=len(a), type=kind)
    if bounds:
        item.update(min=a.min(axis=0).tolist(), max=a.max(axis=0).tolist())
    g['accessors'].append(item)
    return len(g['accessors']) - 1


def read(index, width):
    a = source.accessors[index]
    v = source.bufferViews[a.bufferView]
    return np.frombuffer(source_blob, dtype='<f4', count=a.count * width,
                         offset=(v.byteOffset or 0) + (a.byteOffset or 0)).reshape(-1, width).copy()


def image_bytes(index):
    v = source.bufferViews[source.images[index].bufferView]
    return source_blob[v.byteOffset:v.byteOffset + v.byteLength]


def add_image(data, mime='image/jpeg'):
    g['images'].append(dict(bufferView=view(data), mimeType=mime))
    g['textures'].append(dict(source=len(g['images']) - 1, sampler=0))
    return len(g['textures']) - 1


g['materials'].append(dict(name='ArchitectureColors', doubleSided=True,
                          pbrMetallicRoughness=dict(baseColorFactor=[1, 1, 1, 1], metallicFactor=0, roughnessFactor=0.9)))
materials = {}
textures = {}
groups = defaultdict(lambda: [[], [], [], []])
keep_contents = {'Merged_materials', 'Charcoal', 'material_0', 'ForestGreen', 'SteelBlue',
                 'Low_E_Glass_1', 'Low_E_Glass_2', 'Silver', 'MidnightBlue', 'Low_E_Glass_4',
                 'Metal_Panel', 'Material1', 'Concrete_rough_02', 'GhostWhite',
                 'Tile_small_ceramic', 'material_9', 'Wood_Cherry_Original_2',
                 'Wood_Cherry_Original_2_2', 'material_5', 'material_7', 'material_8',
                 'material_11', 'material_12', 'material_13', 'material_14'}
for mesh in source.meshes:
    category, material_name = mesh.name.split('__', 1)
    if category == 'Contents' and material_name not in keep_contents:
        continue
    for primitive in mesh.primitives:
        mat = source.materials[primitive.material]
        pbr = mat.pbrMetallicRoughness
        factor = pbr.baseColorFactor or [1, 1, 1, 1]
        if pbr.baseColorTexture is None:
            material = 0
            color = factor
        else:
            old_texture = pbr.baseColorTexture.index
            if old_texture not in textures:
                textures[old_texture] = add_image(image_bytes(source.textures[old_texture].source))
            if primitive.material not in materials:
                materials[primitive.material] = len(g['materials'])
                g['materials'].append(dict(name=mat.name, doubleSided=True,
                    pbrMetallicRoughness=dict(baseColorFactor=factor, metallicFactor=0, roughnessFactor=0.9,
                                             baseColorTexture=dict(index=textures[old_texture]))))
            material = materials[primitive.material]
            color = [1, 1, 1, 1]
        pos = read(primitive.attributes.POSITION, 3)
        dest = groups[(category, material)]
        dest[0].extend(pos)
        dest[1].extend(read(primitive.attributes.NORMAL, 3))
        dest[2].extend(read(primitive.attributes.TEXCOORD_0, 2))
        dest[3].extend([color] * len(pos))

# Product photos become case facings instead of thousands of little bottles.
photos = []
for mat in source.materials:
    if ('60x260' in mat.name or mat.name.startswith('Z0_')) and mat.pbrMetallicRoughness.baseColorTexture:
        t = source.textures[mat.pbrMetallicRoughness.baseColorTexture.index]
        photos.append(Image.open(io.BytesIO(image_bytes(t.source))).convert('RGB'))
atlas = Image.new('RGB', (1024, 1024), '#c3bca0')
for i, photo in enumerate(photos[:64]):
    tile = photo.resize((120, 120))
    x, y = (i % 8) * 128, (i // 8) * 128
    atlas.paste(tile.resize((128, 128)), (x, y))
    atlas.paste(tile, (x + 4, y + 4))
encoded = io.BytesIO()
atlas.save(encoded, 'JPEG', quality=88)
atlas_texture = add_image(encoded.getvalue())
product_material = len(g['materials'])
g['materials'].append(dict(name='ProductCaseAtlas', pbrMetallicRoughness=dict(
    baseColorTexture=dict(index=atlas_texture), metallicFactor=0, roughnessFactor=0.9)))


def box(center, size, photo):
    cx, cy, cz = center
    hx, hy, hz = (v / 2 for v in size)
    corners = [(cx + x * hx, cy + y * hy, cz + z * hz)
               for x, y, z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
                              (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    tx, ty = (photo % 8) * 128, (photo // 8) * 128
    uv = [((tx+4)/1024, (ty+124)/1024), ((tx+124)/1024, (ty+124)/1024),
          ((tx+124)/1024, (ty+4)/1024), ((tx+4)/1024, (ty+4)/1024)]
    dest = groups[('Contents', product_material)]
    for face, normal in [((0,3,2,1),(0,0,-1)), ((4,5,6,7),(0,0,1)),
                         ((0,4,7,3),(-1,0,0)), ((1,2,6,5),(1,0,0)),
                         ((3,7,6,2),(0,1,0)), ((0,1,5,4),(0,-1,0))]:
        for i in (0,1,2,0,2,3):
            dest[0].append(corners[face[i]])
            dest[1].append(normal)
            dest[2].append(uv[i])
            dest[3].append((1,1,1,1))


cases = 0
for shelf, x in enumerate([-2.625, -0.875, 0.875, 2.625]):
    for side in [-1, 1]:
        for tier, y in enumerate([0.34, 0.76, 1.18]):
            for column in range(7):
                box((x + side * 0.30, y, -1.38 + column * 0.45), (0.22, 0.25, 0.37),
                    (shelf * 11 + tier * 7 + column) % min(64, len(photos)))
                cases += 1
for tier, y in enumerate([0.45, 0.95, 1.45]):
    for column in range(10):
        box((-2.7 + column * 0.6, y, -2.72), (0.46, 0.30, 0.22), (column + tier * 9) % len(photos))
        cases += 1

triangles = 0
for (category, material), (positions, normals, uvs, colors) in sorted(groups.items()):
    name = category + '__' + g['materials'][material]['name']
    attributes = dict(POSITION=accessor(positions, 'VEC3', True), NORMAL=accessor(normals, 'VEC3'),
                      TEXCOORD_0=accessor(uvs, 'VEC2'), COLOR_0=accessor(colors, 'VEC4'))
    g['meshes'].append(dict(name=name, primitives=[dict(attributes=attributes, material=material)]))
    g['nodes'].append(dict(name=name, mesh=len(g['meshes']) - 1))
    g['scenes'][0]['nodes'].append(len(g['nodes']) - 1)
    triangles += len(positions) // 3
g['buffers'] = [dict(byteLength=len(blob))]
encoded = json.dumps(g, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
blob.extend(b'\0' * (-len(blob) % 4))
result = struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(blob))
result += struct.pack('<I4s', len(encoded), b'JSON') + encoded
result += struct.pack('<I4s', len(blob), b'BIN\0') + blob
(OUT / 'supermarket_mobile.glb').write_bytes(result)
report = dict(triangles=triangles, meshes=len(g['meshes']), materials=len(g['materials']),
              textures=len(g['textures']), product_cases=cases, bytes=len(result))
(OUT / 'mobile_conversion.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
