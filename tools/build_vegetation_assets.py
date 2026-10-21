from pathlib import Path
p=Path('tools/convert_actor_usdz.py').read_text()
p=p[:p.index("if __name__ == '__main__':")]
p=p.replace("('/RootNode/' + root_filter + '/')",'root_filter')
p=p.replace(".convert('RGB')",".convert('RGBA')").replace('image.thumbnail((1024, 1024))','image.thumbnail((512, 512))').replace("image.save(buf, 'JPEG', quality=90)","image.save(buf, 'PNG', optimize=True)").replace("mimeType='image/jpeg'","mimeType='image/png'")
p=p.replace("key = json.dumps(pbr, sort_keys=True)","masked = bool(shader.GetInput('opacity')) and bool(shader.GetInput('opacity').GetConnectedSource())\n        key = json.dumps([pbr, masked], sort_keys=True)")
p=p.replace("pbrMetallicRoughness=pbr, extras=dict(key=key)","pbrMetallicRoughness=pbr, alphaMode='MASK' if masked else 'OPAQUE', alphaCutoff=0.4, extras=dict(key=key)")
# Retain leaf cards; simplify only the dense bark of the animated tree pack.
p=p.replace('if (rv and len(faces) > 2500)',"if (scene == 'vegetation_dense' and len(faces)>2500 and 'Bark' in str(prim.GetPath())) or (rv and len(faces) > 2500)")
p=p.replace("if scene == 'town' and uv", "if scene in ('town','vegetation_dense') and uv")
ns={'__file__':str(Path('tools/convert_actor_usdz.py').resolve())};exec(compile(p,'vegetation_converter','exec'),ns)
for i in [1,2,3]:ns['convert']('Trees.usdz','assets/environment/vegetation',f'tree{i}.glb',scene='town',root_filter=f'/tree{i}/',scale_multiplier=2.0)
ns['convert']('grass.usdz','assets/environment/vegetation','grass.glb',scene='town',root_filter='GrassBase_0/',scale_multiplier=.24)
ns['convert']('grass.usdz','assets/environment/vegetation','reeds.glb',scene='town',root_filter='Grass_Reeds_0/',scale_multiplier=.65)
ns['convert']('Tree_Animate.usdz','assets/environment/vegetation','grove.glb',scene='vegetation_dense',scale_multiplier=1.35)

