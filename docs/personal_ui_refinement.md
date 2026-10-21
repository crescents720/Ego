# 随身装备交互与 HUD 修订

2026-10-17，按本轮反馈替代上一版装备界面的交互。

- 装备界面只显示小萤随身物品。唯一常驻入口为左上圆形头像，在室外、室内和驾驶时均可点击；打开后暂停危险，关闭恢复。家具交互不再打开装备页。房车储物界面、容量及存取按钮全部撤下；原储物家具仅说明后续开放，旧存档内的历史储物数据暂时保留，不在随身页面显示。
- 初始便装属于角色外观，不是装备或背包物品。新游戏六个槽位为空、初始物品重量为零；载入旧存档会移除 hoodie / skirt / shoes 伪装备数据。
- 棒球棍拾取对话配有从真实 3D 模型渲染的透明图片。按钮为“放入背包”，领取后仅加入右侧背包图标格，不自动装备。鼠标或手机触摸按住图标，拖到左手或右手槽位才装备。错误部位拒绝放置，物品保留；支持手部之间换手，不能复制。点击物品或装备图标才显示名称、重量、说明，格子内部不再用文字代替图片。空槽使用对应部位轮廓图例。
- 背包仍限重 10 kg，手持物品仍计入随身负重。当前棒球棍与全部便利店物资共 5.70 kg。图片图标包括棒球棍、食物、瓶装水、医疗用品、材料。棒球棍实际手持动作和五次命中击倒普通丧尸保持。
- 顶部黑色文字状态栏及生命/资源/速度文字撤下，改为圆形头像和血条。5/5 使用健康头像与绿色；4–3/5 为轻伤头像与黄色；2–0/5 为泪眼、疲惫和小绷带的重伤头像与红色。伤害信号直接更新图片及条形长度，新游戏恢复健康状态。剧情目标仍由玩法维护，必要引导放在底部现有提示区域。
- 小地图使用当前主相机的右向量、上向量投影世界地面，建筑改为同样投影后的四边形，玩家朝向和房车朝向也用同一转换。因此主画面往右移动时地图方向也向右，不再沿用世界 X/-Z 的固定映射。北向指示随投影绘制。地图保持固定显示范围，地图放大缩小按钮与其下方画面缩放按钮均撤下；主画面原有滚轮和双指缩放仍保留，界面不占位。

## 生成头像

内置 imagegen 工具，参考 `assets/ui/hotaru_equipment.png`。项目文件：

- `assets/ui/avatars/healthy.png`
- `assets/ui/avatars/hurt.png`
- `assets/ui/avatars/critical.png`

原始生成文件保留；HUD 导入纹理限制到 256 像素，避免三张大图占用不必要的手机显存。生成提示词的共用部分：

> Game HUD avatar for Hotaru from the reference illustration, identity-preserving close-up anime portrait, square composition with entire short black bob haircut and pink hoodie collar visible, face filling most of the frame, same dark brown eyes, clean polished Japanese anime game illustration. Soft muted dusk background, no text, no border, no symbols.

三张分别追加：

> Healthy, calm but determined, gentle cute expression, no injuries.

> Lightly injured but cute: tiny cheek scratch, small pale bandage on cheek, worried soft eyes, slightly untidy hair, no blood.

> Heavily exhausted and vulnerable but still adorable and gentle, big moist eyes with a little tear, small cheek bandage and a few superficial scratches, slightly tousled hair, cute pleading expression, no gore, no bleeding, no frightening imagery.

棒球棍图片 `assets/ui/icons/bat.png` 由 `tools/render_bat_icon.gd` 渲染实际道具模型。其余物品和空槽图例为可扩展的 SVG。

## 验证

- `tools/verify_personal_ui.gd` 图形模式：真实头像点击；三档血条和头像；便装及房车入口移除；带图片拾取且不自动装备；真实鼠标拖拽及手机触摸拖拽；错槽拒绝、换手、点击说明、负重限制。
- `tools/verify_minimap.gd`：世界四方向及相机右方向的投影与主画面一致；实际向右步行；驾驶方向箭头；玩家居中；室内隐藏；无缩放按钮。
- `tools/verify_equipment.gd` 更新为背包先领取、再拖拽装备的流程；10 kg、唯一拾取、持械伤害、存档和旧版便装清理继续验证。
- 完整首日冒烟流程及主画面手势/滚轮缩放回归通过。
- 实际渲染截图由 `tools/capture_personal_ui.gd` 生成：`hud_healthy.png` / `hud_hurt.png` / `hud_critical.png`、`bat_pickup_picture.png`、`personal_bag_icons.png`、`personal_equipped_icons.png`。

## 新版伤势与房车血条

头像改为 110×110，中重伤使用更明显的新版图片；增加房车血条与围攻、撞击、爆炸机制。最新记录见 [房车生存战斗](vehicle_survival_combat.md)。
