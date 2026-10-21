# 房车耐久、尸群碰撞与头像辨识度

2026-10-17。

## 本轮行为

- 小萤头像由 92×92 调整为 110×110；健康头像保留，中伤与重伤换为新版。中伤有明显额头绷带、单侧淤青、眯眼与紧张表情；重伤有更重的双颊淤青、肿眼、哭泣表情和少量鼻口血迹，保持日漫风格、不表现开放伤口或组织损伤。三档仍以 5/5、4–3/5、2–0/5 切换。
- 移除序章逃生阶段对攻击按钮和攻击输入的双重禁用，便利店里也能攻击。可操作的步行阶段保留攻击，驾驶及车内不显示徒手/武器攻击按钮；影片和对话按既有规则锁定操作。
- 小萤血条下方增加向右错开的房车小头像和耐久条，房车图片从实际 3D 模型渲染，没有状态变体。耐久变化直接更新条形与颜色。
- 人在房车生活区或驾驶位，都视为车内有人。附近丧尸会选择车辆作为目标，走近真实车体边缘、播放攻击动作并在接触时损伤车辆。下车后恢复追击小萤，未完成的车身攻击不再隔空结算。

## 初版数值

| 项目 | 当前值 |
| --- | --- |
| 初始房车耐久 | 120 |
| 丧尸攻击车辆 | 每次接触 4 点，仍使用 1.2 秒冷却与 0.44 秒接触时间 |
| 引擎起火与冒烟 | 耐久不高于 50% |
| 车顶加重火势 | 耐久不高于 25% |
| 致命撞击速度 | 接触方向速度至少 4.5 m/s，约 16.2 km/h |
| 每撞倒一只丧尸 | 保留当前速度的 82%，车体损失 2 点耐久 |
| 已有一级防撞装甲 | 最大耐久 160，承受伤害减半，撞击保留 90% 速度 |

车辆碰撞层加入丧尸层。驾驶使用实心车身的连续运动碰撞查询，能够撞到整个车体范围内的丧尸。足速迎面撞击当场击倒目标，立即释放死亡碰撞，并以衰减后的速度继续剩余运动；低速或擦碰无法直接击倒目标，车辆被挡住并停止，踩着油门不能在原地累积车速。连续碰撞会逐次损失动量，前后均被围住时无法简单冲出去。墙体仍能阻挡车辆。

起火目前是耐久阶段的视觉提示，不另增加持续燃烧扣血，避免同时叠加未说明的额外失败计时。装甲升级保留当前耐久比例，读档也按对应升级后的最大值恢复。耐久比例加入既有首日完成存档，旧存档默认满耐久；本轮不新增任意地点存档。

## 爆炸与失败

耐久归零仅触发一次爆炸：扩散火光、火星、闪光灯、爆炸音效及焦黑车体，随后保留燃烧残骸。小萤在生活区或驾驶位时，切回车外展示爆炸、停止车辆、角色死亡，约 1 秒后显示“房车被摧毁了”的重新开始提示。爆炸时人在车外 6 米以内同样致命，远处不会被不合理地隔空杀死。残骸无法再次上车或驾驶。

## 资产与提示词

中伤：`assets/ui/avatars/hurt_v2.png`；重伤：`assets/ui/avatars/critical_v2.png`。使用内置 imagegen 编辑工具，参考 `assets/ui/avatars/healthy.png`，保留旧版作对比。HUD 纹理导入限制为 256 像素，原始图片不改。

共用提示词：

> Edit target is Hotaru's supplied healthy anime avatar. Keep the same character identity, short black bob, brown eyes, pink hoodie, soft dusk background, square framing. Game HUD icon: facial expression and injury must be very readable even at 64 pixels. Cute Japanese anime survival game style, non-graphic injuries, no exposed tissue or gore, no text or symbols.

中伤追加：

> Clearly moderate injury, much more visibly distressed than a healthy portrait: messy hair, prominent forehead bandage, a large dusky purple cheek bruise, several visible red scratches with a small thin trail of dried blood from the eyebrow, one eye squinting with pain and watery eyes, strained worried mouth. Still adorable, brave and vulnerable.

重伤追加：

> Severely exhausted and visibly battered, extremely vulnerable and despairing yet cute: much messier bob hair, a broad stained forehead bandage, pronounced purple bruising on both cheeks, one eye swollen half shut, the other large glossy eye streaming tears, small nosebleed and a thin blood streak at the corner of the mouth, trembling open mouth and deeply worried brows. Very obvious difference from the moderate state, readable silhouette/expression. Non-graphic superficial injuries only, no gore.

房车图标：`assets/ui/icons/rv.png`，由 `tools/render_rv_icon.gd` 原生渲染。爆炸音效为本地合成的低频冲击与衰减噪声，`tools/build_rv_audio.py` 生成 `assets/audio/rv_explosion.wav`，未引入外部音乐。

## 验证

- `tools/verify_vehicle_combat.gd`：开篇攻击按钮及真实攻击；进入生活区后的丧尸目标、接触扣车血及下车取消；实际高速/低速车身碰撞；击倒及降速；前后尸群阻挡；两档火势；一级装甲；耐久读写及升级上限恢复；小图标尺寸；生活区和驾驶位爆炸死亡；延后游戏结束提示；重复致命伤保护。
- 原有空手十击、装备与五击棒球棍、四朝向上下车、开篇实体路线、头像真实点击及鼠标/手机装备拖动、完整首日流程回归通过。
- `tools/capture_vehicle_combat.gd` 图形模式实际渲染：`vehicle_hud_healthy.png`、`vehicle_hud_hurt.png`、`vehicle_hud_critical.png`、`rv_surrounded_fire.png`、`rv_explosion.png`、`rv_explosion_gameover.png`，位于 `artifacts/`。

数值为第一版平衡参数；未进行手机真机压力测试。
