# 人工加工与下车安装

2026-10-19，源码更新，未导出APK。本文取代vehicle_fabrication.md里旧的自动计时/自动安装规则。

## 动作串线修复

工厂门口与房车侧门重叠时，HUD的near_rv分支会将通用交互按钮覆盖成“上车E”，但_interact实际仍优先进入工厂。现在末尾工厂优先分支同时统一文字、提示与动作：通用按钮始终明确“进入工厂”，独立的“侧门上车”按钮只调用_toggle_vehicle进入房车。用真实鼠标点击重叠区域的车辆按钮验证，进入房车且工厂active/transitioning均为false。

## 两阶段操作

每面铁丝围栏加工耗时统一为1游戏小时，即DAY_SECONDS/24=360/24=15秒正常速度。前后仍各消耗4份铁丝、左右各6份，开始扣一次料。配方界面暂停整个游戏和日夜时钟；开始加工关闭配方界面，小萤站在唯一维修工作台操作LatheWork动画，持工具并播放轻工具声，画面显示工作进度和剩余游戏分钟/正常秒数。此时主世界时钟继续，与操作同速推进。

点击“暂停操作”或Esc停止，释放角色控制，当前加工进度保留。离开、睡觉或时间快进都不会代做；回来与车床交互，点击同面“继续加工”接着做，不再次扣材料。窗口失去焦点/手机切后台也停止操作，不会后台代做。

加工满15秒后任务变为install阶段，尚不增加车辆防护，提示玩家下车。下车停在车辆附近，独立“安装围栏”按钮出现；不复用工厂/车辆交互按钮。点击后小萤沿车外路径走到对应一侧，跨侧时绕车头/车尾，不穿车身，然后用RepairKneel蹲下持工具固定。安装需8秒操作时间，走路不计入安装进度；中断/被攻击/道路被挡会保留已完成进度。重新点击可走回继续，完成后才赋予该面500耐久及显示围栏。

加工和安装期间角色由操作控制，普通移动/攻击/上下车按钮隐藏，世界及生存消耗正常进行；配方/其他暂停菜单冻结游戏。正在操作时禁存档；暂停操作后仍可按原安全规则保存。

## 存档与兼容

fence_job由旧side/finish改为side/stage/work/install_work，相同schema5经济节保存。旧任务按原20/30秒截止时间推算已有加工比例并换算到15秒；已到期但未自动产出的旧任务视为待安装，不凭空增加防护。旧档已安装的围栏保持不变。任务各阶段只由advance_fence_work在实际操作时推进，tick_survival不再完成生产。读取时normalize_fence_job迁移，不重置或重复扣料。

## 资产与代码

新增tools/build_workshop_animations.py从hotaru_trolley.glb追加LatheWork，输出hotaru_workshop.glb作为角色入口，保留原战斗/维修/推车/睡眠动画。重建顺序为service→trolley→workshop；射击替身仍用hotaru_gunnery.glb不变。

vehicle_fabrication.gd管理配方、操作卡片、暂停、工具、绕车行走及安装按钮；main._process在fabrication.active时仍推进世界时间，mobile_joystick接入独立安装按钮。main新局/加载会停止操作并关闭菜单，已有暂停进度随GameState读取。

## 验证

verify_manual_fabrication通过：工厂门口停车的真实上车按钮点击、配方菜单冻结昼夜、正常操作昼夜与工作计时同步、LatheWork动画、15秒加工、全局暂停冻结、中途停止/睡眠不代做、隔离存档后续作不重扣、加工不自动安装、下车绕车到对侧、蹲下安装、8秒安装中断续作、旧任务迁移。Vulkan截图manual_craft_menu/manual_craft_work/manual_fence_install已检查。

更新verify_fabrication以适应人工两阶段流程，扣料/四面/500次/修理/存档回归通过；verify_trolley_doors、verify_rv_gunnery、verify_factory、verify_vehicle_services回归通过。测试采用user://manual_craft_test/slot.cfg等隔离目录，未修改用户存档。未导出APK、未做真机验证。
