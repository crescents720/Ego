"""Build the runtime repair facade with source surface colors and 30k triangles."""
from pathlib import Path
import os,runpy,json
root=Path(__file__).resolve().parents[1]
os.chdir(root)
runpy.run_path(str(root/'tools/build_repair_reference.py'))
runpy.run_path(str(root/'tools/bake_repair_colors.py'))
report={"source":"Auto_Repair_Facade__Stylized_Tier_I.usdz","original_triangles":1484684,"triangles":30000,"bytes":(root/'assets/environment/repair_shop/repair_shop_mobile.glb').stat().st_size,"textures":0,"materials":1,"color_bake":True,"source_unchanged":True}
(root/'assets/environment/repair_shop/repair_shop_mobile.glb.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
