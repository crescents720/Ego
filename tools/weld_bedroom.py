from pathlib import Path
p=Path('tools/convert_actor_usdz.py');s=p.read_text(encoding='utf-8-sig');needle='        original_triangles += len(faces)\n';s=s.replace(needle,needle+'''        if scene == 'bedroom':
            # CAD export duplicates vertices at virtually every face. Weld
            # positions before decimation; keep representative UVs per point.
            _, first, mapping = np.unique(np.round(points, 5), axis=0, return_index=True, return_inverse=True)
            points = points[first]
            vertex_uv = vertex_uv[first]
            faces = mapping[faces].astype(np.int32)
            faces = faces[(faces[:,0] != faces[:,1]) & (faces[:,1] != faces[:,2]) & (faces[:,0] != faces[:,2])]
''',1);p.write_text(s,encoding='utf-8')
