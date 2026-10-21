# 房车双侧射击窗与 M60

2026-10-19，安卓第五版，Godot 4.6.3。

## 操作

在武器店买到 M60 后，用推车运回房车并完成装卸；机枪和弹药必须在房车货舱。车内步行靠近左、右射击窗，按 E / 交互即可架枪并切换到越肩视角。同一把枪可换到另一侧，退出不会复制或丢失武器。点击“拆卸机枪”后才可在管理菜单转移或丢弃。

电脑：按住右键拖动瞄准，按住左键连续开火，E / Esc 或“收枪离开”返回车内。手机：右侧拖动瞄准，左下按住开火，支持独立双指；右下离开或拆卸。上方显示余弹和车辆耐久，设置暂停会清除持续开火状态。

有效距离100米，瞬时命中，不计算下坠；射速每0.12秒一发，每发5伤害，普通10HP丧尸两发击杀。地形和建筑阻挡子弹，击杀照常掉现金。弹药从货舱逐发扣除，没有额外生成弹药或引入换弹系统。小萤不能在车外手持此枪。

## 实时性与模型

车内和射击时均保持车辆占用状态，外部世界时间、丧尸移动及攻击房车持续运行；小萤留在车内不受外部直接攻击，车辆被毁仍会导致失败。普通暂停菜单维持原来的暂停行为。

左侧灶台区域向车头压缩，移除一组吊柜；右侧移除靠床座椅与碰撞。两侧都做开放射击窗和搁枪台。外部房车也切出对应孔洞、加窗框，原始模型保留。

关键文件：scripts/actors/rv_gunnery.gd、scripts/environment/rv_interior.gd、scripts/actors/rv.gd、scripts/main.gd。hotaru_gunnery.glb 只用于射击替身，原有角色动画入口不变。生成器 tools/build_rv_gunnery_assets.py 与 tools/build_gunnery_animations.py 可重建，后者在 trolley 动画资产之后运行。

存档 schema5 新增 economy.m60_window，旧档默认未架设，保存弹药及架设侧；射击过程中不允许保存，退出后可正常保存。不修改玩家现有存档。

## 验证

verify_rv_gunnery 通过：双侧交互、货舱前置、扣弹与射速、两枪击杀与掉落、95/101米边界、墙体阻挡、双指瞄准开火、暂停清理、空弹、退出恢复、架设禁止移动、隔离存档往返、车内/射击实时受击、车毁失败。vehicle_services、rest_save_repair、mobile_input_store、cash_shop_trolley、cart_mobility、cheat_store_refresh 回归通过。死亡异步测试退出会产生既有资源未释放提示，不属于运行中的脚本报错。

画面截图 artifacts/gunnery_interior_left.png、gunnery_interior_right.png、gunnery_shoulder_left.png、gunnery_shoulder_right.png 已检查。

机枪音效：KuraiWolf 的 Light Machine Gun，CC BY 4.0，见 licenses/RV_Gunnery_Audio.txt；来源 https://opengameart.org/content/light-machine-gun 。

## 安卓测试包

builds/android/FireflyRoad-0.1.20261019.5-arm64-debug.apk，versionCode5，约230MB，同包名及签名，可覆盖安装。v2/v3签名、16KB对齐通过。模拟器实测走到窗口、架枪、按住开火扣弹、拖动瞄准、退出恢复车内；最终镜头修正后再次确认准星无遮挡，日志无脚本错误。使用独立模拟器测试档，未接触玩家存档。尚未在真实手机验证性能。精确哈希见 build_info-revision5.json。

## 2026-10-19 窗口与菜单修正（尚未导出）

用户要求后续累积几轮修改再整体导出，不要每轮打APK。当前源码比第五版APK更新；本轮未动导出版本或重新打包。

管理菜单说明增加自动换行、固定说明区最低高度，储备卡不再强制192px最低宽度；720×1280验证面板(22,100)大小676×1139，M60长说明与关闭按钮完整留在屏幕内。左窗移除RouteMapBoard、RouteMapPaper、MapRoute_*，并加入_replaced_shell避免裁切/高亮恢复遮挡。

外部GLB射击开口改为原始坐标y1.90～2.60、z1.32～2.55，面积约旧口30%，重新从原始模型切割；窗框同步缩到车辆局部y.49～1.02、z.99～1.91。rv_gunnery.exterior_mounted左右各一个M60视觉件，仅对应已架设侧显示，无枪/拆卸即隐藏，射击时改用肩后模型避免重复，行驶时保留。左右共用同一库存枪，没有复制武器物品。

verify_rv_gunnery扩展检查长说明菜单边界、路线板隐藏及车外枪架设侧，全部通过。Vulkan截图gunnery_dashboard_wrapped、gunnery_exterior_mounted、gunnery_interior_left/right、gunnery_shoulder_left/right均检查。
