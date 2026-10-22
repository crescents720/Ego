# 《末日与黎明》新窗口接手文档

更新：2026-10-22。这是当前状态的入口；聊天附件与历史文档仅作背景，不要把旧需求重新全部执行一遍。

## 如何继续

项目绝对目录：`C:/Users/ding5/Documents/Ego`。Godot 4.6.3，主场景 `scenes/main.tscn`，入口控制器 `scripts/main.gd`，自动加载 `scripts/core/game_state.gd`。使用本地项目继续修改，无需新建项目或下载全部素材。用户偏好中文、主动完成、简洁说明；用户没有要求多代理。

Godot 控制台程序：
`C:/Users/ding5/Downloads/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe`

Python：`C:/Users/ding5/AppData/Local/Python/pythoncore-3.14-64/python.exe`。已有 pxr/USD、numpy、fast_simplification、pygltflib、Pillow；ffmpeg/ffprobe 可用。USDZ 原件在 Downloads，不要覆盖。

优先阅读本文件及 `docs/rest_save_repair.md`、`docs/day_cargo_revision.md`。README 中较早的过程记录有过时数值，以本文件和最新实现为准。`docs/home_handoff.md` 是之前搬家时的旧交接。

## 2026-10-22 大太刀四连击实装（当前）

用户确认视觉上可辨认的四刀版本先进入游戏。寺庙取得大太刀后，普通攻击现固定播放`SwordCombo4`：斜斩→反向上挑→横斩→举刀下劈，总时长2.66秒，四个独立命中点为.432/.945/1.468/2.072；每刀伤害4、距离2.4m，逐刀复核正面夹角、距离和墙体遮挡。四连期间锁定角色位移，完整收势后才能重新攻击；原目标死亡或离开范围后，后续刀可寻找正面最近目标。`SwordCombo5`技术上确有第五刀，但因视觉近似收势，留待后续太刀术训练。未新增存档字段。

`verify_sword.gd`已改为验证SwordCombo4、四个独立窗口、防重复命中、完整收势与四刀墙体阻挡。拾取提示、物品说明、README及`docs/odachi_temple.md`已同步。仍未导出APK。

## 2026-10-21 大太刀动作第二版

用户否定第一版：手臂穿模、挥剑逻辑及美感不足。已重做，优先读docs/odachi_temple.md顶部。核心是修复蒙皮，不只是IK：tools/repair_hotaru_arm_skin.py识别真实独立臂/手组件，修正肩肘腕位置、逆绑定和原动画平移，去掉前臂绑躯干/躯干绑手臂的错误；鞋底整体随本脚防踏步拉三角。build_sword_animations.py在workshop来源上先repair再追加新Sword动画，hotaru_sword仍入口。其他原件不动。

手掌空间握刀而非腕骨直接放在刀柄上；R前L后11.5cm，hotaru附件增加掌心偏移+轴向转换。步伐/重心/转髋/收势重做，握点跟随躯干平移，横斩刀刃随切面转动。当前1/2/3/4/5段时长1.0/1.49/2.03/2.66/3.56，命中元数据.432/.945/1.468/2.072/2.796。120fps导入保留。

新验证verify_sword_surfaces.py对实际蒙皮后的前臂/手部逐帧测试胸腹头部核心体积（并非任意衣服褶皱精确碰撞）；另双角度检查渲染，verify_sword手掌握持/伤害/保存通过，equipment/manual_fabrication/trolley_doors通过，棒球棍画面核对。新动图artifacts/sword_v2_combo1～5.gif，生成器preview_sword_v2.gd/build_sword_v2_previews.py。旧sword_combo*.gif是被否定版本，勿展示为最新。未打APK。

## 2026-10-21 寺庙大太刀与五套连击动作（源码最新，未导出）

见docs/odachi_temple.md。新增Shinobi_Temple原模型到(-94,345)，北横路z300转支路，小地图“寺庙”；前殿入口地面刀架E取唯一大太刀，需2.2kg背包，自动右手栏双手握持，清左手装备但保留物品。odachi_taken进economy_defaults兼容旧档，新游戏复原。大太刀拆除素材独立刀鞘，减到29k三角/1.1MB，原USDZ不动。

当前攻击SwordCombo4，四刀各4伤害、2.4m，总时长2.66秒，命中点.432/.945/1.468/2.072，保留朝向、距离与墙体检查；普通10HP丧尸在第三刀倒下。SwordCombo1～3和5继续作为独立动作资源，未来训练可复用；斜斩→上挑→横斩→下劈→斜斩收势，时长1.0/1.49/2.03/2.66/3.56秒。双手IK和膝部/躯干变化，无根位移。人物入口hotaru_sword.glb，保留旧动画并新增SwordIdle/Walk/Combo1～5；build_sword_animations.py在workshop后生成，**GLB.import fps120必须保留**，低采样手会离柄。刀和棍同附件容器，服务/推车/坐下/死亡隐藏逻辑保留。刀音效暂复用挥动/肉击。

verify_sword覆盖实际按钮/唯一拾取/满包/双手/握点/四段命中窗口/墙/完整收招/推车/坐下/隔离保存加载/新局/道路无树草。artifacts/sword_v2_combo1～5.gif为当前实际骨架双视角动图，旧sword_combo*.gif不要作为新版展示。当前刀在前院刀架获取，未做独立寺庙内场景。训练后续再做。用户不要求本轮APK，仍未导出。

## 2026-10-20 手机驾驶拆分（源码最新，未导出）

用户确认左手左右转向、右手油门/刹车、停车D/R，要求按键不遮挡。见docs/mobile_driving.md。新mobile_driving.gd在驾驶时隐藏步行摇杆与其他动作，左右踏板两行分布，停车按钮移踏板上方、下车还原。双指独立、刹车优先不倒车，停车才切D/R；触屏平滑回正/高速减敏/倒车限2.5m/s，键盘驾驶不变。RV触屏输入与walking touch_move独立，不受旧摇杆重置。暂停/后台清除，无粘油门。

verify_mobile_driving全输入/物理/无重叠/恢复/桌面检查通过，Vulkan截图mobile_driving_layout.png已核对；旧mobile_input_store驾驶斜推预期按新设计改为不响应步行摇杆，其他功能保留。trolley_doors、vehicle_services回归通过。没有导出APK，第六版仍旧操作。

## 2026-10-19 安卓第六版（最新已导出）

用户已要求导出整合当前源码。APK为builds/android/FireflyRoad-0.1.20261019.6-arm64-debug.apk，versionCode6，242717713字节，同包名同debug签名；签名v2/v3、16KB对齐、ZIP CRC通过。export_android.ps1默认路径和export_presets版本升为6。包含以下各轮工厂/推车/人工加工安装/围栏等全部修改；以下旧“未导出”是当时历史状态。精确哈希及模拟器验证见builds/android/build_info-revision6.json。用户电脑/手机存档未改动，模拟器测试使用隔离fixture。

## 2026-10-19 上车/工厂文字串线与人工加工安装（源码最新，未导出）

优先读docs/manual_fabrication.md，取代旧自动生产规则。工厂与RV门重叠时通用按钮被near_rv误标“上车E”但动作进工厂；现工厂分支最后统一按钮/提示，独立侧门上车实际点击验证只进RV。

每面加工1游戏小时=15正常秒，必须小萤在唯一工作台做LatheWork+手持工具，带进度条；配方选择菜单全局暂停，开始加工关闭菜单且昼夜/操作同步。暂停按钮/Esc/切后台停止并保留，回来车床续作，睡眠不代做。完成变待安装，防护仍0；下车附近独立安装按钮，绕车走对应面后蹲下RepairKneel安装8秒，也可中断/续作/攻击中断。结束才500HP。操作中禁保存，停止后按原安全规则存。

fence_job现在side/stage/work/install_work，normalize迁移旧finish按比例保进度，不自动装。tick_survival移除自动产出。新hotaru_workshop.glb追加LatheWork作为角色入口，生成器build_workshop_animations.py在trolley后运行；机枪替身未动。verify_manual_fabrication图形/实点击/昼夜同步/绕车/暂停续作/存档/旧档通过，fabrication和推车门/机枪/工厂/维修回归通过。无APK。

## 2026-10-19 推车门口判定与留室内消失修复（源码最新，未导出）

见docs/trolley_door_fix.md。doorway_points将人和正在推的近旁车中心/前缘/前角作联合门口判定，覆盖店/厂进出、武器店进入；远处松手车不参与。main._is_near_store_exit统一HUD和交互，末尾推车HUD不再隐藏门口进出按钮。

重要根因：int(cart_position.x/1000)会将工厂左半2998判为2、便利店左半1998判为1，导致视觉消失。现在GameState.spatial_room_id使用roundi最近原点，推车与现金均同步。已有坐标/货物不迁移不重置，室内松手后出入保留。verify_trolley_doors全流程双店/先车进出/停放重入/货物/隔离存档通过；factory、cart_mobility、mobile_input_store、fabrication回归通过。本轮无APK。

## 2026-10-19 铁丝高亮、通用窗口与围栏生产（源码最新，未导出）

优先阅读docs/vehicle_fabrication.md。铁丝加蓝白脉动光柱/闪点；窗边标签/家具名称去掉M60限定改左/右侧窗口，枪功能ID保留。唯一车床位为用户圈出的原工作台；安装后交互开vehicle_fabrication生产面板，货舱铁丝前后各4份20秒/左右各6份30秒，只能单任务，扣料后关闭菜单运行，世界时钟/休息推进，完成直接安装对应一面。经济fence_hp/fence_job在schema5兼容保存。

每面500次丧尸攻击耐久，实际Zombie前摇接触后调用RV.take_zombie_hit，保护对应面并扣1，击毁隐藏，下一次才伤车。车辆碰撞仍伤车体。修车厂允许满车体但围栏受损时维修，12秒逐步恢复、中断保留，只修hp>0、不复活击毁面。新fence.glb来自用户USDZ，JPEG白底网格转透明并用菱形shader保远处可见；车身侧面附着围栏，窗口上方无遮挡，无新增物理墙阻门。

verify_fabrication完整计时/扣料/四面/真实丧尸/500次/维修/存档通过；factory与机枪/维修/休息存档/手机便利店回归通过。artifacts/fabrication_menu、vehicle_fences、factory_inside图形已检查。用户仍要求累积改动后才打APK，本轮未导出。第五版APK不含这些源码变化。

## 2026-10-19 工厂原内部恢复（源码最新，未导出）

用户指出内部偏小；检查原始转换模型确认它自带约10×15m、7m高通高厂房，前轮“只有外壳”的判断错误。现在room/OriginalFactoryInterior直接用factory.glb，删掉自建3.8m高矮盒，保留砖墙/高窗/水泥地/屋顶原材质，只添简单生产线。按实际内墙而非装饰柱外沿匹配碰撞x±4.74,z±7.20，门口镜头避免原卷帘遮挡。车床/铁丝位置、入口和测试同步更新。外门cut也纠正到真实门面z5.45～5.90，宽4m，并同步卷帘。详情docs/factory.md末尾。verify_factory通过、Vulkan原件内部及游戏截图检查完成，本轮无APK。

## 2026-10-19 工厂、铁丝与车床（源码最新，未导出）

优先阅读docs/factory.md。工厂模型在(-66,250)，正门(约-63.25,242.6)，朝向常规镜头，连接西侧路。factory.gd交互卷帘上升进入独立车间ORIGIN(3000,0,0)，近距第三人称右键/右侧触屏转视角，墙体缩镜头。每次2～3丧尸，出门清理。铁丝首4份0.5kg，每45秒世界时间补1、最多6，未满时段保留、快速进出不刷新；推车优先否则背包。单台24kg车床需推车近旁且有空间，取走不再生，既有门口卸车后在RV工作台交互确认安装。未实现加工/加固。factory经济字段兼容schema5保存，室内禁保存。

推车/现金房间隔离扩展为0街道/2店/3工厂；暂停正确清理镜头并暂停敌人。用户原USDZ不动，新转换工具build_factory_assets.py和assets/factory资源，简单几何车间。verify_factory完整流程/触摸/暂停/存档通过，机枪/手机便利店/推车/现金/作弊店刷新五项回归通过。截图artifacts/factory_*.png已检查。用户要求积累几版再整体导出，本轮没有打APK，现有第五版保持不变。

## 2026-10-19 机枪窗口与管理菜单修正（源码最新，未导出）

用户明确以后积累几轮修改再整体导出APK，本轮不要打包。第五版APK不含本轮修正。详情docs/rv_gunnery.md末尾：管理菜单status自动换行/min72，卡片不强制宽；长M60说明边界验证通过。左窗RouteMapBoard/Paper/MapRoute_*移除并加入替换壳体列表。外部射击口面积缩至原约30%，build_rv_gunnery_assets.py重新生成bounder_hatches.glb；窗框同步。新增exterior_mounted模型随m60_window左右架设显示，拆卸隐藏，射击替身期间隐藏避免重复。gunnery测试与Vulkan截图通过。现有APK保留不变。

## 2026-10-19 房车双侧M60射击（最新）

优先阅读 docs/rv_gunnery.md。车内左右射击窗已接入，左灶台压缩移前/移除一组吊柜，右床端座椅及碰撞移除，外部房车 bounder_hatches.glb 也有对应孔洞。枪及弹药必须先推车卸进货舱；靠窗E进入越肩射击，电脑右键拖动+左键开火，手机拖动+左下双指开火，E/Esc/右下离开或拆卸。100m hitscan，5伤害/发、0.12秒/发，普通丧尸两枪。消耗货舱弹药，世界及车辆受击持续；车毁失败。架设枪不能从管理界面移走，拆卸后可移动。m60_window在schema5存档兼容保存，射击中禁存。

新增 rv_gunnery.gd、hotaru_gunnery.glb、m60_mounted.glb、模型/动画生成器和 verify_rv_gunnery 测试。战斗范围/遮挡/双指/暂停/空弹/存档/实时车辆受击/车毁测试及六项回归通过，图形截图已检查。音效CCBY4 KuraiWolf已署名。安卓第五版信息见 builds/android/build_info-revision5.json。

## 2026-10-19 作弊码与便利店供货/刷新（最新）

优先阅读 `docs/cheats_store_refresh.md`。局内Enter/右上齿轮打开暂停的作弊码菜单，`showmethemoney`每次+10000现金，可重复；新增 `test_settings.gd`，触屏齿轮接入独立手指路由。其他模态暂停菜单、影片和商店对话时不开。

所有便利店货架无限供货，旧looted仅访问历史，不禁用货架；旧store_stock只为兼容，不再影响take_stock。保留负重，数量界面显示持续供货。不要恢复成每店6桶/12包或已拿过不能再取。

店内初始2只，每180秒世界时间+1～2，最多6存活；击杀不立刻补回，快进同样推进、最多6、不积压刷新欠账。`store_residents`与`store_next_refresh`存在survival节（schema5兼容）；店外逻辑人数计时，入店空闲过道生成，距玩家至少2.5m。新测试verify_cheat_store_refresh通过，mobile_input_store/cart_mobility/day_survival/cargo_input回归通过。安卓新版code4约225MB，模拟器实测齿轮输入代码0→10000、旧空库存架取水并再次打开正常，签名与16KB对齐通过；见build_info-revision4.json与新文档末尾。

## 2026-10-19 现金、武器店和推车（最新）

优先阅读 `docs/cash_weapon_trolley.md`。schema 5 兼容旧档：现金、现金掉落、交易状态、推车内容/位置/部署偏好均保存。丧尸死亡（含车撞）1～5 元银行钞票掉落，绿色光柱；步行 1.25m 自动拾取，车里不拾取；180秒世界时间过期（睡眠推进）。左上新增现金图标金额。

小地图武器店位于(112,154)，门(107.8,.95,153.8)，有接入道路。`weapon_shop.gd` 为伪2D对话，生成背景加提供店员模型的透明 SubViewport 立像；初访完整、回访简短，1000元原子交易，M60+500发+推车，缺钱赶走。M60 23kg，弹药游戏重量2kg，满推车25kg；本轮仅取得运输，尚无射击/车载安装。

`cargo_trolley.gd` 推车48%速度、不能攻击，可随时松手/重推（含店内），新增独立推车按钮接入手机独立手指。可带进便利店、取物选择背包或近旁推车；远处或留店推车不能凭空传送。靠房车侧门上车：约2秒搬货+折叠推车，再进室内；不足空间拒绝，死亡/车毁不扣货。管理菜单设定下车自动部署，安全放门旁；三栏分别背包10kg、房车1000kg、推车25kg。房车内部各处都可开管理，储物柜现开管理。

角色入口改为 `hotaru_trolley.glb`，保留服务/战斗动画加PushIdle/PushWalk；重建顺序service后运行 `tools/build_trolley_animations.py`。四个USDZ由 `build_weapon_assets.py` 转换，M60 144586→40864面，UV岛独立简化、重建顶点采用原组质心并检查范围，避免细小零件QEM出界；务必图形检查 `artifacts/trolley_push.png`。背景生成提示词及内置工具记录在新文档。

新测试 `verify_cash_shop_trolley`、`verify_cart_mobility`、mobile_input_store回归通过，图形截图 `capture_cash_shop.gd` 已检查。其他车辆服务/睡眠存档回归通过。所有存档测试隔离，未改用户存档。

安卓新测试包 `builds/android/FireflyRoad-0.1.20261019.3-arm64-debug.apk`（code3，约225MB），同签名包名；已导出，签名与16KB对齐检查通过，Android模拟器已实际完成1000元付款、推车货物25kg检查、摇杆推行、装卸收车（货舱确认枪/500发）和下车自动部署；日志无脚本错误。另修复暂停对话时隐藏摇杆吞左下模拟鼠标点击，`verify_shop_mobile_dialogue` 实际点支付按钮回归通过。详见新文档末尾。旧APK保留。

## 2026-10-18 安卓第二版：摇杆、出店、新封面和图标（最新）

最新版 `builds/android/FireflyRoad-0.1.20261018.2-arm64-debug.apk`（version/code=2，约208MB），同包名同签名覆盖安装保留手机存档。已替换用户提供的新封面和安卓 icon，源文件 assets/ui/title_background.png 与 android_icon.png 原样复制，安卓主图标/自适应前景背景均配置。Godot 导出模板仍使用前轮校验的官方4.6.3，别改回全局旧模板。

安卓方向按钮换成 `scripts/ui/mobile_joystick.gd`，手指ID独立管理，右手动作按钮可在左手持续摇杆时触发；桌面非触摸仍保留方向键按钮。hotaru/rv 的 touch_move 为独立模拟量，不模拟键盘；暂停、松手、离开窗口清零。坐驾驶座摇杆隐藏时，起身/开始驾驶按钮仍可触摸。

便利店出口由出生点1m球改为正门前过道Rect2水平区域，HUD与交互统一调用 `store_interior.is_near_exit`，近门按钮显示“离开便利店”，取完食物和水进入RETURN_TO_RV后仍可退出。

详情 `docs/mobile_controls_store_fix.md`。新测试 `verify_mobile_input_store.gd` 使用 Input.parse_input_event + flush_buffered_events 验证斜向、双指、不粘住、取物后出店、驾驶席按钮；store_entry/store_navigation 回归通过。安卓模拟器已安装启动并实际检查拖动中的摇杆，包内 icon 已提取核对。最终APK已用隔离的“已拿食物和水”测试档实际触摸进店、摇杆移至偏离原入口点的门前，再按“离开便利店”回街道，成功且日志无脚本错误。重导出脚本 `tools/export_android.ps1` 默认输出第二版，精确SHA见build_info-revision2.json。

## 2026-10-18 Android APK 测试包（最新）

用户要求导出手机测试 APK。产物 `builds/android/FireflyRoad-0.1.20261018-arm64-debug.apk`，约 208 MB，包名 com.fireflyroad.dawn，ARM64，Android API 24+、target 36，保持 Vulkan Mobile。APK v2/v3 签名验证、Android API37 模拟器安装、标题和游戏内场景检查已完成；尚未连接真实手机，模拟器性能不能代表真机。文档 `docs/android_apk.md`，复现 `tools/export_android.ps1`，安装说明及构建 SHA256 在 builds/android 下。

本机 Android Studio JBR25 和 SDK/build-tools36 可正常导出，Godot 全局路径已配置。重要：全局 export_templates/4.6.3.stable 目录其实放的是旧4.6模板，**不要用于当前项目导出**；Android debug 预设指定官方 `source/export_templates/4.6.3/android_debug.apk`，文件内部版本已确认4.6.3。没有配置正式 release 签名/模板。

开启 Android ETC2/ASTC 纹理导入；导出排除 tools/docs/artifacts/source/builds 等非运行文件，加入许可证文本。Android 测试发现 AudioDirector 在重载时读取旧节点的临时错误，已补齐场景/角色/车辆树状态检查，`verify_audio_lifecycle.gd` 通过。用户现有电脑存档未改动。

## 2026-10-18 车位校准、喘息轮换与 25% 红血（最新）

详见 `docs/service_positions_breathing.md`。加油位已从外侧道路移至油泵和站房之间，中心 `(51.5,1.02,-136.5)`；检修位已对齐修理厂正面，中心 `(105,1.02,-135)`。新画线和操作判定共用 BAY 常量；旧存档车辆位置保留，玩家自行驶入新车位。

“声音”入口仅标题界面显示，局内不显示。黄/红血各三种喘息组合，用洗牌袋轮换，禁止相邻重复，间隔随机；红血部分包含微弱痛吟与实录喘息的拼接。单一阈值 `hotaru.CRITICAL_HEALTH_RATIO=.25`：0 独立死亡，0<HP<=25% 红色重伤，25%<HP<=50% 黄色，>50% 健康；头像和喘息一致。来源/许可继续见 `licenses/Audio_Revision3.txt`。验证 `verify_vehicle_services`、`verify_audio_revision2`、`verify_rest_save_repair` 均通过，已图形检查车位。

## 2026-10-18 下车作业、加油站与日语女声（前一轮）

优先阅读 `docs/vehicle_services_and_voice.md`。修理厂正面已转向默认镜头；房车玻璃实际向上延伸封住缺口；小萤六条受击/倒地/黄红血喘息已统一换为日本演员录音，许可和必须保留的署名在 `licenses/Audio_Revision3.txt`，声音设置已有署名。

修车不再瞬间完成：停车下车后现场免费操作，走到车旁蹲下检修，4/8 秒换位置，累计工作 12 秒修满，取消保留部分耐久。新增 `vehicle_service.gd`、`hotaru_service.glb` 两个作业动画。加油站使用用户 `Old_Gas_Station.usdz` 转换资源（27,604 三角面，3.83 MB），在修理厂西侧，沿白线车道中心 `(45.7,1.02,-136.5)` 停车后下车加油；3 L/秒自动加满 60 L，允许随时中断、保留实际升数。正反停车与绕过车身到油泵均已验证。攻击中断作业，世界照常推进，作业禁止存档。

新验证 `tools/verify_vehicle_services.gd`，新截图脚本 `tools/capture_vehicle_services.gd`。音频、车辆战斗、睡眠存档旧回归也通过。接手不要把修车恢复成旧的瞬间修满，也不要重新生成 revision2 女声覆盖当前日本女声。若重建角色：先生成 combat/bat/rest，最后运行 `build_service_animations.py`。

## 2026-10-18 音效重做与免费检修（前一轮）

音乐基准提高 8 dB；脚步调轻并由步行动画落脚方法轨触发（实测 2.1 秒 4 次）。已用实录替换脚步、挥棒、肉体打击/车撞肉体、发动机点火及循环、丧尸受击/死亡声、蛍受伤/倒地与黄红血喘息；去除战斗和死亡相关的合成单音。车辆独立抬臂前摇，0.60 秒接触才结算一次，攻击人物仍 0.44 秒。修理厂现场免费检修，不再收集或消耗材料；停车、安全与现场条件仍保留。

规则、来源、重建顺序与测试见 `docs/audio_revision2.md`，优先于下方旧记录。新验证 `tools/verify_audio_revision2.gd`，图形截图 `tools/capture_audio_revision2.gd`。`licenses/Audio_Revision2.txt` 包含 CC0 录音与 qubodup 引擎 CC BY 3.0 署名，声音页已更新。

## 2026-10-18 音频实装补充

已接入三首作品四个配乐版本（标题 Signal to Noise、探索 No Piano Melody、房车 Undertow、追逐 Lightless Dawn），70 个音效文件中 39 个为 Kenney CC0 录制素材，其余为程序合成初版。右上“声音”可调五类音量、查看署名；影片保留原声。入口 `scripts/core/audio_director.gd` 自动加载，设置页 `scripts/ui/audio_settings.gd`。源码/许可/重建与限制见 `docs/audio_implementation.md`。

新增验证：Godot 图形模式 `--path . --script tools/verify_audio.gd`；设置页截图 `artifacts/audio_settings.png`，实际输出样本 `artifacts/audio_title_sample.wav`。音乐、淡变与冷却使用真实时间，睡眠不加速音频；车内围车声做相对位置映射。真实手机听感尚未验证。

## 最新一轮已全部实现

1. RV 车顶与挡风玻璃连续斜封边，已检查正面渲染。
2. HP >50% 绿/健康，15%～50% 黄/中伤，0～15%（不含端点）红/重伤；0 独立死亡。
3. 车内床睡眠回血，选择时长，30 倍世界快进，360 秒游戏时间恢复满额最大 HP；攻击、补给耗尽立即中断。完整规则见最新记录。
4. 六槽保存/读取、覆盖确认、战斗禁存、旧档迁移。
5. 北部修理厂、停车检修、材料换耐久，优化模型已接入。
6. 已完成桌面回归与截图检查，当前没有本轮待完成需求。下一步等待用户的新指示。

## 游戏形态与操作

3D 手机竖屏 720×1280，桌面窗口 450×800，Mobile 渲染器。室外斜 45°正交视角；人物移动跟随屏幕方向。WASD/方向键或触屏方向按钮，E 交互，J 攻击，Space 驾驶/停车。户外滚轮/双指缩放主镜头，无缩放按钮。小地图按镜头方向投影，避免再次改成方向相反的俯视图。

标题新游戏→15 秒竖屏影片→火灾逃生→绕后院上房车→衣柜取哥哥棒球棍→首次驾驶触发便利店补给指引→进店选水和面包→存回车内货舱。衣柜拾取先入背包，拖到左/右手槽后才装备。旧的哥哥线索、返回装甲升级原型结局仍保留。

标题图 `assets/ui/title_background.png`；影片 `assets/story/video/opening_v2.ogv`，720×1280，保留原视频声音，无机器人旁白、无“序章萤火未熄”标题。影片来自用户最新优化版，不要回退旧片。

## 角色、装备、车辆

- 小萤最大 HP=5，浮点生命，名字仅“蛍”。运行角色 `assets/characters/anime-girl/hotaru_rest.glb`，含 Idle/Sit/Walk/Punch/Hit、左右持棍 Idle/Walk/Attack、Death、Sleep 等 13 个片段，26 关节。原角色为静态模型自动蒙皮，裙摆/手部仍有精修空间。
- 普通丧尸 HP10，空手伤害1需10拳；棒球棍伤害2需5击。攻击有接触时点、受击、死亡。丧尸有行走、游荡、啃咬动作。
- 左上圆头像打开个人装备与背包。头、双手、上下身、脚六槽；原本衣服不是装备，槽默认空。背包含装备限重10kg。图标点击看说明，拖拽配置。
- 物品：棒球棍0.9kg；水每桶5L/5kg；面包每包0.5kg；药0.15kg；维修材料0.35kg。
- RV 货舱1000kg，与随身背包分开。驾驶座有管理面板与“货物整理”双栏拖拽/丢弃界面，支持数量选择。
- RV HP120，一级装甲最大160并减伤。≤50%起火、≤25%更强；毁车爆炸杀死乘员/6米内小萤并 Game Over。死亡有扑倒动画后再失败提示。
- 外观统一缩放0.75，右侧中部门上下车。上车镜头固定最终车内角度、小萤迈步进门，不要加车身旋转过渡。低速与丧尸体积阻挡；≥4.5m/s撞杀，速度乘0.82（装甲0.90），损车2（装甲1），围车可困住。

## 昼夜、生存与敌人

一天360秒有效游戏时间，白天180/夜晚180，从06:00起；菜单/暂停/过场/失败不推进，无离线追赶。睡眠是例外：主动让整个世界30倍推进。

每天水5L、食物1kg；每360秒消耗1桶水，每180秒1包面包，先随身后货舱。包装按整件计重直至消耗。缺水1080秒、缺食1800秒线性耗尽满HP；同时缺乏采用较快损血率，不叠加。存档记录时钟与消耗进度。

油箱60L、开局6L，每实际行驶1000m消耗1L，倒车算，顶墙空转不算；暂未实现加油系统。

`zombie_population.gd` 按街道区域生成，白天每区目标3、夜晚9；附近105米激活，远150米隐藏停用。清空约9秒后从附近建筑方向补充，避开玩家/车18米与视线。夜晚追逐5.2m/s=小萤速度，白天0.85，夜晚游荡2.6。商店内2只独立敌人，击杀保留；进店暂停户外敌人。

存档与睡眠共用 `main.is_under_attack()`：敌人近身攻击范围或车辆最近3秒有攻击均视为危险。丧尸开始车辆攻击前摇就触发唤醒，非等扣血才醒。

## 地图与模型

普通房屋约343栋，来自 CCity 五种低层模型。植被约五千组，以 MultiMesh 按40米区块分组，草65米、树130米可见；道路、车位、任务地块避让。普通建筑按实际墙面生成碰撞，剔除停车平地，不要重加整块占地大盒子。前景遮挡建筑淡化至0.16。

道路 x=-120/-60/0/75/150，z=-100/0/100/200/300，东侧湖；范围 x[-165,315]、z[-165,415]。功能地块仍有医院、工厂、武器店、五金店、警局等预留，未全部实现。

关键坐标：

| 位置 | 世界坐标 |
|---|---|
| 着火住宅 | (-11,0.08,-43) |
| 初始 RV | (-21.5,1.02,-43)，朝向 PI |
| 便利店入口 | (7.5,0.95,51) |
| 修理厂建筑 | (105,0.07,-140) |
| 黄色检修位 | (105,1.02,-125) |
| RV 室内原点 | (1000,0,0) |
| 商店室内原点 | (2000,0,0) |
| 开篇卧室原点 | (3000,0,0) |

修理厂源模型约148万面，运行 `assets/environment/repair_shop/repair_shop_mobile.glb` 3万面、0.96MB、顶点色。白墙红色立面，细节简化。重建 `tools/build_repair_shop.py`；原始中间资源 `output/model_work` 有 `.gdignore`，不要导入运行。检修不消耗材料；蛍与房车在修理厂现场、停车且安全才可执行。

## 代码定位

- `scripts/main.gd`：阶段、镜头、输入、交互、模拟协调。
- `scripts/core/game_state.gd`：库存、负重、资源、昼夜与序列化。
- `scripts/actors/hotaru.gd` / `rv.gd` / `zombie.gd`：角色和战斗。
- `scripts/story/rv_sleep.gd`：床与快进。恢复退出时必须还原 Engine.time_scale、镜头、角色、控制；死亡同样清理。
- `scripts/ui/save_slots.gd`：六槽界面；`equipment_screen.gd`：个人；`rv_dashboard.gd`：车辆面板。
- `scripts/environment/repair_shop.gd`：修理厂；`town_layout.gd`：路网地块；`zombie_population.gd`：街道补怪。
- `scripts/story/opening.gd`：开场；`escape_trail.gd`：金色虚线。
- `tools/`：资产生成与验证；`docs/`：各轮设计记录。

## 存档与测试安全

实际存档目录：`C:/Users/ding5/AppData/Roaming/Godot/app_userdata/末日与黎明/saves/slot_1.cfg` 至 `slot_6.cfg`。旧档 `firefly_road_save.cfg` 存在时仅复制到空槽1，不删除。schema4 包含生命、车况、位置朝向、油、世界时间、背包/装备/货舱、商店库存与任务。读取在车门外恢复小萤，不保存精确室内站位。槽1会自动保存，槽2～6手动。

测试使用 `suppress_save` 或隔离 `slot_directory`，不得覆盖用户进度。底层 `save_game` 战斗中返回 ERR_BUSY，不应绕开。

最近验证通过：

```powershell
# 以下在项目根目录，$godot 指向上面的控制台程序
& $godot --headless --path . --editor --quit
& $godot --headless --path . -- --smoke-test
& $godot --headless --path . --script tools/verify_rest_save_repair.gd
& $godot --path . --script tools/verify_six_slots_ui.gd
& $godot --headless --path . --script tools/verify_vehicle_combat.gd
& $godot --headless --path . --script tools/verify_day_survival.gd
```

部分更早的 UI 测试仍按历史布局/物资数字编写，不要盲目为满足旧断言改回旧规则。最新图像在 `artifacts/rv_sealed_windshield.png`、`sleep_pose.png`、`six_save_slots.png`、`town_repair_shop.png`。`tools/capture_rest_repair.gd` 可重新截取。

已在本机 Intel Graphics 上验证，尚无手机帧率/发热测试。需要后续关注快进时敌人密集区与夜间的性能；素材蒙皮与美术细节仍为原型水平。修理厂为消耗材料交互，无修车技师剧情或维修动画；不存在尚未完成的本轮阻塞。
