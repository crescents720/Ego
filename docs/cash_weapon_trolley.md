# 现金、神秘武器店与推车

更新：2026-10-19。

## 玩法

- 左上头像与生命条下显示钞票图标及现金。新游戏 0 元；旧存档自动补齐此字段。
- 每只丧尸死亡（包括车辆撞杀）恰好掉落一份 1～5 元现金。小钞票模型有绿色竖直光柱。必须下车、步行靠近 1.25 m 才会自动拾取。
- 180 秒世界时间后消失，等于半个游戏日。暂停不推进；睡眠快进推进。金额、掉落位置、到期时刻均存档。
- 武器店在小地图“武器”处，新增道路从 X=75 接到店门，正门面向默认镜头。靠近正门交互进入独立的伪 2D 对话，显示当前说话者与底部文字。
- 初访完整对话，后续简短询价。少于 1000 元会被赶走；足够时可拒绝或付款。一次性交易：1000 元兑换 M60、500 发弹药及赠送推车，不能重复扣款或领取。
- M60 搬运重量 23 kg，弹药按游戏重量 500 发合计 2 kg；总重正好装满推车 25 kg。M60 无法放入 10 kg 背包，也没有随身装备槽。本轮是取得与搬运流程，射击及安装车载武器尚未接入。
- 推车必须走近后按“推行推车”；速度为普通步行 48%，双臂推行新动画，不能攻击。随时按“松开推车”或 J 松手，恢复正常移动和攻击；推车留在现场。
- 推车可以带进便利店，拿取食物、水时可选择背包或附近推车。也可以松手留在店里，回店重新推走；离店不会自动把远处推车带出。
- “推车货物”可选择物品和数量在随身/推车间转移，严格分别计重。房车管理的“货物整理”分随身 10 kg、房车 1000 kg、推车 25 kg 三栏。停在远处的推车不能通过房车菜单远程搬运货物。
- 推至房车右侧门按上车，约两秒搬运货物与折叠收车动画，完成后货物全量进入房车货舱；容量不够则拒绝装卸，不丢货。过程中禁止存档；死亡或车辆毁坏不扣除货物。
- 房车管理点“使用推车 / 下车时自动部署”切换部署偏好；下车会在门旁选择安全空位部署。已留在外面的推车不能凭空召回。房车内部各处均可打开管理。
- schema 5 存档保存现金、掉落物、交易、推车货物/位置/部署偏好。读取时暂停推行，推车仍在原处，包括便利店内部。

## 实现

`cash_drops.gd`：复用网格/材质，10 Hz 拾取及过期扫描，光柱使用发光透明着色，无额外逐掉落点光源。
`weapon_shop.gd`：外观、碰撞、对话及交易；店员使用提供模型的透明 SubViewport，不额外生成替代人物。
`cargo_trolley.gd`：推行、碰撞探测、物品选择与转移、装卸、部署和进出店。
`game_state.gd`：资源、容量与原子交易、存档。
`mobile_joystick.gd`：将推车操作与货物按钮加入独立手指分发，保持双指操作。
`hotaru_trolley.glb`：保留原战斗/睡眠/维修动画，新增 PushIdle / PushWalk；重建顺序：service 后运行 `tools/build_trolley_animations.py`。

四个原始 USDZ 均保留在 Downloads，由 `tools/build_weapon_assets.py` 转换。武器店 9,117 面，店员 11,488 面，推车 3,104 面，M60 从 144,586 面减少为 40,864 面并保留 UV 岛。M60 纹理上限 512，其他上限 1024，Godot 继续生成 LOD。转换输出约 15.8 MB；原件不覆盖。

## 图像生成记录

使用内置 imagegen 工具，新增原创背景 `assets/weapon_shop/interior.png`，941×1672，已目视检查后放入项目。提供的参考图片仅用于理解氛围和用途，未直接复制为背景。

最终提示词：

Create a production game background illustration, portrait 9:16, for a Japanese anime post-apocalyptic survival mobile visual novel. Inside a small mysterious gun shop, seen from customer's eye level facing a long dark wooden sales counter. Dusty stone walls, wooden ceiling beams, fluorescent lamps, shelves and glass rifle cabinets behind counter, neatly displayed old machine guns, ammunition boxes and a heavy M60 lying on counter. Abandoned town atmosphere, sinister but safe and quiet, muted brown olive tones, subtle warm light at counter, beautifully painted detailed visual-novel background, no people, no text, no UI, no logos. Keep central counter visible and leave bottom quarter relatively dark for dialogue overlay. Original artwork.

## 验证

- `verify_cash_shop_trolley.gd`：死亡单次掉落、随机区间、驾驶/车内不拾取、步行拾取、180 秒到期、缺钱/有钱分支、扣款与完整礼包、拒绝重复购买、23 kg 不可进背包、推行禁攻击/松手恢复、隔离存档往返、远处推车不传送、装卸/禁止中途存档、自动部署、不堵车门、容量与拆分转移。
- `verify_cart_mobility.gd`：实际移动距离，推行减速、松手恢复，进出店与货架通道、4 桶水进入推车，留车不传送，重取推车，双指移动时松手。
- 回归：mobile_input_store、vehicle_services、rest_save_repair 通过。
- 图形模式 `capture_cash_shop.gd`：`artifacts/cash_shop_street.png`、`weapon_shop_dialogue.png`、`trolley_push.png`、`trolley_inventory.png`。实际 Vulkan 渲染已检查。
- 测试存档使用独立 `user://economy_test/slot.cfg`，未修改用户槽位。


## 安卓实际安装检查

APK `builds/android/FireflyRoad-0.1.20261019.3-arm64-debug.apk`（code3，约225MB）已安装到 API37 ARM64 模拟器。实际触摸读取隔离测试档，进入武器店、逐句对话、点击左下“支付1000元”，确认现金1000→0；返回街道查看推车货物，M60×1、弹药×500、25/25kg；触摸推行并拖动摇杆，再按侧门上车完成装卸收车；房车管理确认货舱内M60×1、弹药×500，开启自动部署后下车，空推车已部署。截图 `artifacts/android_economy_*.png`；日志无脚本/崩溃错误。未连接真机，模拟器不代表真机性能。

此过程发现并修复：隐藏摇杆在暂停对话时仍吞掉其旧矩形内的模拟鼠标事件，导致支付按钮无反应。现在非游戏控制状态直接放行。新增 `verify_shop_mobile_dialogue.gd` 使用模拟鼠标实际点击暂停界面左下按钮，验证成功扣款。重新导出的最终APK已再次实际触摸付款成功。

几何范围检查 `verify_weapon_asset_bounds.py` 通过；禁止直接使用产生超出原始范围顶点的简化结果。重导出使用 `tools/export_android.ps1`；完整SHA256见 build_info-revision3.json。签名 v2/v3、16KB 对齐已验证。
