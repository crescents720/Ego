from pathlib import Path
p=Path('tools/convert_actor_usdz.py');s=p.read_text(encoding='utf-8-sig');s=s.replace("            faces = faces[(faces[:,0] != faces[:,1]) & (faces[:,1] != faces[:,2]) & (faces[:,0] != faces[:,2])]", """            faces = faces[(faces[:,0] != faces[:,1]) & (faces[:,1] != faces[:,2]) & (faces[:,0] != faces[:,2])]
            area = np.linalg.norm(np.cross(points[faces[:,1]]-points[faces[:,0]], points[faces[:,2]]-points[faces[:,0]]),axis=1)
            faces = faces[area > 1e-8]
            _, unique_faces = np.unique(np.sort(faces,axis=1),axis=0,return_index=True)
            faces = faces[unique_faces]
            if len(faces) == 0:
                continue""")
s=s.replace('        pos = points[faces]','        pos = points[faces]\n        valid = np.isfinite(pos).all(axis=(1,2))\n        faces = faces[valid]\n        pos = pos[valid]\n        if len(faces) == 0:\n            continue',1)
p.write_text(s,encoding='utf-8')
