"""Remove only the front-centre column; preserve roof, side pillars and floor."""
import numpy as np

def without_entry_column(vertices, triangles):
    points = vertices[triangles]
    low, high = points.min(axis=1), points.max(axis=1)
    column = ((low[:, 0] > -.27) & (high[:, 0] < .27)
              & (low[:, 2] > 4.40) & (high[:, 2] < 4.87)
              & (low[:, 1] > 1.10) & (high[:, 1] < 4.60))
    return triangles[~column]

if __name__ == "__main__":
    from pygltflib import GLTF2, BufferView
    from pathlib import Path
    path = Path("assets/temple/temple.glb")
    gltf = GLTF2().load(str(path))
    data = bytearray(gltf.binary_blob())
    def read(index, columns):
        a = gltf.accessors[index]
        view = gltf.bufferViews[a.bufferView]
        return np.frombuffer(data, dtype={5126: "<f4", 5125: "<u4", 5123: "<u2"}[a.componentType],
                             count=a.count * columns, offset=(view.byteOffset or 0) + (a.byteOffset or 0)).copy().reshape(-1, columns)
    removed = 0
    for mesh in gltf.meshes:
        for primitive in mesh.primitives:
            vertices = read(primitive.attributes.POSITION, 3)
            original = read(primitive.indices, 1).reshape(-1, 3)
            faces = without_entry_column(vertices, original)
            removed += len(original) - len(faces)
            if len(original) == len(faces): continue
            payload = faces.astype("<u4").tobytes()
            data.extend(b"\0" * (-len(data) % 4))
            gltf.bufferViews.append(BufferView(buffer=0, byteOffset=len(data), byteLength=len(payload), target=34963))
            data.extend(payload)
            accessor = gltf.accessors[primitive.indices]
            accessor.bufferView = len(gltf.bufferViews) - 1
            accessor.byteOffset = 0
            accessor.componentType = 5125
            accessor.count = faces.size
            accessor.min = [int(faces.min())]
            accessor.max = [int(faces.max())]
    if removed:
        gltf.buffers[0].byteLength = len(data)
        gltf.set_binary_blob(bytes(data))
        gltf.save_binary(str(path))
    print("Removed entry column triangles:", removed)
