from pathlib import Path
p=Path('tools/convert_actor_usdz.py');s=p.read_text(encoding='utf-8-sig')
s=s.replace('def convert(filename, folder, output, rv=False):','def convert(filename, folder, output, rv=False, scene=""):')
s=s.replace('if not rv:\n        boots', 'if not rv and not scene:\n        boots',1)
s=s.replace('if rv and len(faces) > 2500:', 'if (rv and len(faces) > 2500) or (scene == "bedroom" and len(faces) > 600):',1)
s=s.replace('target = max(600, int(len(faces) * 0.18))','target = max(120, min(2200, int(len(faces) * 0.015))) if scene == "bedroom" else max(600, int(len(faces) * 0.18))',1)
s=s.replace('''        dest = groups[mat_id]
        dest[0].extend(pos.reshape(-1, 3))
        dest[1].extend(np.repeat(normals, 3, axis=0))
        texcoords = vertex_uv[faces].reshape(-1, 2)
        texcoords[:, 1] = 1 - texcoords[:, 1]
        dest[2].extend(texcoords)''','''        uv_faces = vertex_uv[faces].copy()
        uv_faces[:, :, 1] = 1 - uv_faces[:, :, 1]
        categories = np.where(pos[:, :, 1].max(axis=1) > 2.35, 'Shell', 'Contents') if scene == 'bedroom' else np.full(len(faces), 'Model')
        for category in np.unique(categories):
            mask = categories == category
            dest = groups[(str(category), mat_id)]
            dest[0].extend(pos[mask].reshape(-1, 3))
            dest[1].extend(np.repeat(normals[mask], 3, axis=0))
            dest[2].extend(uv_faces[mask].reshape(-1, 2))''',1)
s=s.replace('for mat_id, (pos, normals, uv) in groups.items():','for (category, mat_id), (pos, normals, uv) in groups.items():',1)
s=s.replace("name = g['materials'][mat_id]['name']", "name = category + '__' + g['materials'][mat_id]['name']",1)
p.write_text(s,encoding='utf-8')
