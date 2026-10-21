# 睡眠、六存档位与修理厂（2026-10-18）

**最新修订：** 音效重做、车辆前摇和免费现场检修规则见 [2026-10-18 后续记录](audio_revision2.md)，相关旧规则以下仅作历史记录。

本记录对应当前已实现版本。后续接手先读项目根目录 `NEXT_WINDOW_HANDOFF.md`。

## 本次行为

- 房车车顶与前挡风玻璃之间改为连续斜面封边，并补齐两侧裙边，不再用一块水平板去覆盖斜接缝。
- 小萤生命值：大于 50% 为绿色健康头像；15%～50%（含两个端点）为黄色中伤；低于 15% 为红色重伤；死亡独立灰色头像。
- 在车内靠近床交互可选择半天、一天或 1～24 游戏小时睡眠。一天为 360 秒游戏时间，恢复最大 HP 的 100%；半天恢复 50%。实际以 30 倍速度推进，半天约需现实 6 秒。
- 睡觉时有躺卧骨骼姿态；世界、昼夜、丧尸和饮食消耗共同推进。车辆正在受袭、已毁、人在驾驶位或车上饮水/食物为空时不能开始。丧尸开始攻击车辆时立即醒来，补给耗尽时停止，玩家也可主动起床。
- 存档改为六个槽位，显示日期、生命与油量；覆盖旧档需确认。槽位 1 同时承担原有自动存档，2～6 为手动槽。受到攻击、即将被近身攻击或睡眠中禁止保存；底层保存函数也执行同样检查。
- 旧单文件存档仅在槽位 1 不存在时复制迁移，原文件保留。
- 小镇北部新增汽车修理厂，黄色检修位中心世界坐标 `(105, 1.02, -125)`。将房车停在附近，点击“检修房车”，可使用维修材料修满车辆。每缺少 30 点耐久需 1 份材料，向上取整；修复会熄灭受损火焰。受袭、行驶、距离过远或材料不足时拒绝，确认时再次检查。

## 资产与轻量化

源模型 `C:/Users/ding5/Downloads/Auto_Repair_Facade__Stylized_Tier_I.usdz` 保持原样。原始约 148 万三角面、33.9 MB；运行资产 `assets/environment/repair_shop/repair_shop_mobile.glb` 为 30,000 三角面、961,456 字节（约 0.96 MB）。

源模型由多个导出块构成，分块减面会破坏外观。本版本合并焊接后整体减面，将原贴图表面颜色烘焙为顶点色，保留轮廓与白墙红色店面，细碎图案有所简化。原始中间 GLB 位于 `output/model_work`，通过 `.gdignore` 排除，不是运行资源。

重建工具：`tools/build_repair_shop.py`（调用 reference 与 bake 两个脚本）；睡眠角色资源由 `tools/build_rest_pose.py` 生成 `hotaru_rest.glb`。不要恢复之前被淘汰的分块减面版本。

## 核心文件

- `scripts/story/rv_sleep.gd`：睡眠界面、快进、恢复、打断和状态还原。
- `scripts/ui/save_slots.gd`：六槽保存/加载界面。
- `scripts/core/game_state.gd`：存档序列化、旧档迁移与安全校验。
- `scripts/environment/repair_shop.gd`：修理厂、停车位与材料修车。
- `scripts/actors/rv.gd`：车顶连续封边、敌袭信号、修复。
- `scripts/actors/zombie.gd`：攻击前摇开始及接触时通知车辆受袭。
- `scripts/actors/hotaru.gd`：躺卧动作与休息状态。
- `scripts/main.gd`：共同安全判断、睡眠期间模拟推进、死亡清理。

## 验证结果

Godot 4.6.3 编辑器导入无报错；首日 smoke test 通过。

- `tools/verify_rest_save_repair.gd`：通过，0 错误。覆盖生命分档边界、真实快进半天、恢复量、世界时间、丧尸接近后唤醒、补给耗尽打断、空补给禁止、底层战斗禁存、生命存取、修车费用与受袭拒绝。
- `tools/verify_six_slots_ui.gd`：实际界面点击通过，0 错误。六槽、覆盖确认、生命值读取和战斗禁存；使用隔离测试目录。
- `tools/verify_vehicle_combat.gd`：通过。逃生攻击、车辆目标、碰撞减速、围车、火焰、装甲与爆炸死亡。
- `tools/verify_day_survival.gd`：通过。
- 图像复核：`artifacts/rv_sealed_windshield.png`、`sleep_pose.png`、`sleep_duration_menu.png`、`six_save_slots.png`、`town_repair_shop.png`。

以上为桌面实机/自动化验证；尚未测量手机上的帧率、发热和多点触控体验。
