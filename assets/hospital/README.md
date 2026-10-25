# Hospital runtime kit

User-provided USDZ sources remain unchanged in C:/Users/ding5/Downloads. See each JSON manifest and ../../docs/hospital.md for source mapping, conversion and integration details.

Build exterior with `tools/build_hospital_assets.py`; build the seven curated furniture kits with `tools/build_hospital_furniture.py`. The latter removes source architectural shells and keeps the source material colours and texture UVs. It no longer applies a universal pale material. `tools/build_hospital_kit.py` additionally extracts individual beds, a neonatal device, a monitor, an office workstation and the reception desk, so room dimensions do not depend on whole reference scenes. Original source archives are not bundled here. No new license claim is made for user-provided assets.

Full-detail reference conversions live in artifacts/hospital_reference_models (ignored by Git and Godot), not in the runtime kit.

校园资产：campus_wall 来自 Fence_retaining_wall.usdz 的 4 m 围墙段；campus_gate_posts/left/right 来自 Gate_01.usdz，拆分门柱和左右铰链门扇，保留原纹理。转换脚本 tools/build_hospital_campus.py。

2026-10-25：外观资源本身不重烘焙，hospital.gd 对外观与室内建筑统一应用水平2倍、竖直1倍。家具以独立逆缩放节点保留人体尺度；原始资源尺寸与游戏内建筑尺寸不再相同。
