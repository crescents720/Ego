# 小镇植被与小萤倒地演出 · 2026-10-17

## 已接入

- 将用户 Downloads 中的 `Trees.usdz` 拆为三种枯树；将 `Tree_Animate.usdz` 中沿 X 排列的三棵阔叶树拆开，并保留少量完整树群。后者不为每棵树运行原始动画骨架，而使用轻量顶点风摆。
- `grass.usdz` 分成低草和湖岸芦苇。保留透明 PNG 和裁切叶片，纹理上限 512；树干适度减面。
- 固定种子产生 1,300 处摆放：345 棵单树、3 处树群、850 处草丛、102 处芦苇。住宅街区内部、镇边和湖岸分别使用不同密度。枯树占少数，阔叶树为主。
- 排除车道、人行道、建筑完整包围盒（含模型自带停车坪）、功能建筑预留场地、湖水、湖岸步道、小萤家/后院/逃生路线与便利店入口。草木目前是装饰，不额外设置挡路的碰撞。
- 按 40 米区域共享网格，用 MultiMesh 批量绘制。草/芦苇显示距离 65 米，树木 130 米；批次原点在各自区域中心。地图总览可临时解除距离限制。

## 死亡流程

`hotaru_survival.glb` 保留原有 11 个徒手、持棍和移动片段，追加 1.65 秒非循环 `Death` 骨骼动画：受冲击后仰、屈膝失衡、倒地、落地微弹、停住。按蒙皮后的顶点计算每个关键帧的地面高度，避免直接旋转整个人造成穿地。

致命啃咬记录攻击者，双方转向，丧尸做短距离扑咬，小萤向后倒下。立即关闭操作、方向按钮和头顶名牌，隐藏手持武器，头像切换死亡状态；约 1.95 秒后才显示失败面板，尸体保持最终姿势。房车爆炸的角色死亡也使用该骨骼动画。重新开始恢复角色、碰撞和健康头像。

死亡头像：`assets/ui/avatars/dead.png`。使用现有重伤头像作身份和风格参考，保持短黑发、粉色连帽衫和额头绷带；双眼闭合、头部垂侧、冷灰色调，避免和重伤状态混淆。游戏导入尺寸为 256，原图保留。

生成提示词（内置 imagegen）：

> Create one square anime game HUD death-state portrait of this exact same character, matching face, short black bob, pink hoodie, forehead bandage and high quality illustration style. Close cropped face centered for a tiny circular avatar. Both eyes completely closed, head slumped gently sideways, lips softly parted, utterly limp unconscious expression. Cold desaturated blue-gray lighting and subdued gray blurred background make this unmistakably distinct from her warm red injured portrait. Keep non-graphic minor scratches and bandage only; no new blood, no gore, no open wounds. Fully clothed shoulders, portrait only. No text, no symbols, no frame. This is the defeated/death status icon in a fictional survival game.

## 验证

- `verify_vegetation_death.gd`：逐处验证摆放禁区、植物种类/数量、批次中心；致命伤触发骨骼动画/死亡头像/操作隐藏；落地前不出现失败提示、落地后不恢复 Idle；新游戏恢复。
- `verify_forecourts_escape.gd`：三个停车坪进出、墙体、开场镜头和尸群攻击。
- `verify_vehicle_combat.gd`：房车受击、起火、围堵、撞击及两种乘车爆炸死亡（更新等待时间以覆盖完整倒地）。
- `verify_equipment.gd` 与完整首日 `--smoke-test` 通过。
- 用实际渲染检查街景、湖岸、死亡头像与落地画面。桌面 Godot 4.6.3 验证，尚未做手机真机帧率测量。

复建工具依次为 `build_vegetation_assets.py`、`split_leaf_trees.py`、`build_death_animation.py`。用户原始 USDZ 文件未修改。
