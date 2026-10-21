# 小萤装备、负重背包与初始棒球棍

2026-10-17。

## 玩家流程

左上角头像打开装备界面。左侧为透明立绘及头部、左手、右手、上身、下身、脚部六个部位；右侧为背包。点击背包物品后选择对应部位装备，点击已装备部位可卸下。棒球棍可装备在左手或右手，同一件物品不能同时占两个部位；穿戴的初始便装也有重量。头部与两手初始为空。

界面打开时暂停单人游戏，关闭后恢复，避免玩家阅读装备时受到攻击。驾车时也能查看。标题页、影片和对话期间不能打开。

首次进入房车，目标栏出现小萤的独白：“不能再空着手了……哥哥的棒球棍还在衣柜里。”门内通道可以实际走到衣柜旁，按 E / 交互打开双扇柜门，看见柜内棒球棍，并触发无配音对白：

> 小萤：我不能再空着手了……
>
> 哥哥的棒球棍，还在老地方。
> 先借我用一下，等找到你，再还给你。

“收下并装备”把棒球棍放入携带物品并装备到右手；“先放着”保持柜内物品。超重时棍仍留在柜里；领取后柜内模型消失，重复交互不会复制。柜门保持开着，再次交互可以关闭，之后仍能开关。

## 负重与储物

限重使用整数克计算，正好 10,000 g 可以接受，超过就拒绝整个拾取批次。穿戴、手持与未装备物品均计入随身重量，换手或卸下不会改变重量；房车储物不占随身负重。

| 物品 | 单件重量 |
| --- | --- |
| 哥哥的棒球棍 | 0.90 kg |
| 粉色便装 | 0.35 kg |
| 格纹短裙 | 0.30 kg |
| 运动鞋 | 0.45 kg |
| 食物 | 0.25 kg |
| 瓶装水 | 0.50 kg |
| 医疗用品 | 0.15 kg |
| 维修材料 | 0.35 kg |

初始穿戴共 1.10 kg，携带棒球棍后 2.00 kg，拿齐当前便利店四处物资后 6.80 kg。便利店先检查重量，成功后才标记已搜刮；拒绝时资源、货架标记和线索状态不变。在房车里，背包页面可将未装备物品存入房车，或切换到房车储物取回；取回同样检查 10 kg。已装备物品须先卸下，避免同一物品被储存和使用两次。现有房车物资箱交互也会打开储物页面。

物品、穿戴、房车储物及棒球棍领取标记随现有首日完成存档保存；旧存档的资源会迁移为有重量的物品。本次不扩展任意地点即时存档。

## 模型与动作

用户的 `Survival_Kit__Part_1__Baseball_Stick.usdz` 转换为 1,632 三角面、单材质和单纹理的 GLB，运行时长度 0.85 米，手柄端为原点。原 USDZ 不修改。资产在 `assets/items/baseball_bat/bat.glb`。

角色保留原来的空手动作，新增左右手各自的 BatIdle、BatWalk、BatAttack 共六段骨骼动作，放在 `hotaru_equipment.glb`。棒球棍通过 Hand.L / Hand.R 骨骼附件跟随真实手部，持械走路保留原腿部运动；入座驾驶时收起手持模型，起身恢复。挥击包括蓄力、挥击、收回，0.40 秒接触判定，每次有效命中伤害 2，普通 10 血丧尸需五次；空手仍为伤害 1 / 十次。仍保留距离、朝向、墙体遮挡和每次动作只伤害一次的检查。

衣柜替换原来的实心家具块，重新搭出背板、侧板、顶底板，两扇门绕真实侧铰链转动，约 0.48 秒完成，开启约 125 度，门把手跟随。柜内有轻微暖光，便于辨认棒球棍。

服装目前为已有便装的装备数据与部位管理，没有新增防具模型或减伤数值；装备界面立绘为静态纸娃娃，穿戴操作不会重绘立绘。后续新防具可以加入同一物品表及对应视觉资源。

## 立绘资产

内置 imagegen 编辑工具生成透明抠图，已确认 RGBA 与真正透明的 alpha；角色白色衣服和鞋子仍为不透明。游戏直接使用 `assets/ui/hotaru_equipment.png`，UI 以主体区域显示整个人物，并从头肩区域取头像，没有另造角色。原始输入保留不动。

最终提示词（背景提取，内置工具）：

> Use case: background-extraction. Edit target: the supplied full-body anime girl illustration. Remove only the white background and floor shadow, producing genuine transparent alpha for a game equipment paper-doll UI. Preserve the exact girl identity, face, hair, pose, pink short sleeve hoodie, white shirt, blue checked skirt, legs and both shoes. Keep the complete head-to-toe character with small transparent margins, centered. Preserve fine hair edges and opaque white clothes and shoelaces. No redesign, no added objects or text.

## 验证

- `tools/verify_equipment.gd`：实际从车门走到衣柜、超重拒绝且道具保留、恰好 10 kg、唯一领取、左右手与部位限制、储物取回、头像打开与暂停恢复、真实五击战斗及接触时间、新旧存档恢复、便利店超重后货架保持原样。
- `tools/verify_bat_animation.gd`：图形模式验证左右手持械 Idle / Walk / Attack，步行动画保留腿部运动、挥击手骨实际移动约 0.53 米、骨骼附件正确。
- 既有 `verify_combat.gd` 空手十击与受击流程、`verify_actor_models.gd` 四方向上下车、`verify_store_navigation.gd` 商店导航、完整首日冒烟流程均通过。
- `tools/capture_equipment.gd` 实际渲染装备界面、初始武器对白、柜门打开与柜内道具；`tools/preview_bat.gd` 渲染持械待机、蓄力与挥击。截图在 `artifacts/`。

构建：`tools/build_equipment_assets.py` 在转换好的 source.glb 及原战斗角色模型基础上生成道具与新增动作，不覆盖原角色模型。

## 最新交互修订

本页早期房车储物、初始便装装备及自动装备流程已被替代：现在仅随身背包，初始六槽为空，拾取后必须拖到手部栏位。最新行为和截图见 [本轮修订](personal_ui_refinement.md)。
