# 修理、加油与日语女声更新 · 2026-10-18

本记录优先于旧的即时修车、旧女声与旧车顶封边说明。停车位、喘息轮换和 25% 红血的进一步修订见 `service_positions_breathing.md`。

## 现在的玩法

- 修理厂正面已转向默认镜头，建筑移到 `(113,.07,-135)`；黄色检修位位于正门前 `(105,1.02,-135)`。
- 房车停稳后，小萤必须下车，再点“检修房车”。免费，不消耗材料。她会绕开车头走到可见的一侧，蹲下检修；累计工作 4、8 秒时换位置，累计工作 12 秒修满。走路时间另算。
- 修理过程逐步恢复耐久；按“中断操作”或 Esc 停止，已经修好的部分保留。
- 加油站已加入修理厂西侧，原点 `(50,0,-135)`。实际加油车道中心 `(51.5,1.02,-136.5)`，沿 Z 轴，正反停车均可。中心横向容差 .55 米、纵向 1.8 米，方向偏差约 20 度内，车速低于 .3。
- 停到油泵旁白线车道后下车，点“加油”。小萤会走向油泵一侧，手持油枪，软管连接最近油泵。3 L/秒，自动加到 60 L；中断按实际已加升数保留。空箱最多约 20 秒工作时间，另加走路时间。
- 作业期间世界和丧尸继续活动，饥渴继续计算。附近出现攻击、人物死亡、车毁、车辆移动等会中断。作业期间不能存档；声音/装备菜单暂停世界时也暂停作业。
- 检修位换边时先绕过保险杠，不穿过房车；加油反向停车也验证了绕车到油泵侧的路线。

## 视觉和资源

`scripts/story/vehicle_service.gd` 管理作业过程、进度、取消、移动和油枪软管；`scripts/environment/gas_station.gd` 管理实物、碰撞、车道条件与加油入口。小萤模型新增 `RepairKneel` 和 `FuelHold` 循环，沿用原骨架及战斗、步行、睡眠动画。生成脚本 `tools/build_service_animations.py`，运行资源 `assets/characters/anime-girl/hotaru_service.glb`。

原始 `C:/Users/ding5/Downloads/Old_Gas_Station.usdz` 未修改。`tools/build_gas_station.py` 转为 `assets/environment/gas_station/gas_station_mobile.glb`：27,604 三角面、4 材质、贴图上限 1024，约 3.83 MB。原件约 11.7 MB；几何量适中，主要压缩贴图，移除额外法线/金属/遮蔽贴图。角色被屋棚或站房挡住时，只淡出对应部件，保留地面。

加油站为用户提供的本地模型，保留源路径及转换元数据；没有擅自赋予第三方模型新的开源许可。

房车新增与原玻璃同斜率、同蓝色的上部玻璃面，覆盖旧玻璃顶边到车顶封边的空洞，两端略重叠防漏。先前仅加车顶封边仍会漏空，这一轮实际延伸了玻璃。

## 小萤配音

受击 3 条、倒地 1 条、黄血及红血各 3 种喘息，共 10 个文件，全部替换为「あみたろの声素材工房」同一位日本演员的录音；没有沿用旧欧美女声，也没有用提速变调模拟少女声。具体来源、署名及许可边界见 `licenses/Audio_Revision3.txt`，游戏声音页可查看署名。处理与源文件哈希见 `source/audio/japanese_voice/sources.json`，重建脚本 `tools/prepare_japanese_voice.py`。

## 验证

- `tools/verify_vehicle_services.gd`：驾驶中拒绝作业、修理不瞬间完成、实际绕车到岗、逐步修复、取消保留、完成修满、停车位置/朝向限制、实际走到油泵、反向停车绕车、逐步加油、取消保留、自动加满、受攻击中断、存档阻止。
- `verify_audio_revision2.gd`、`verify_audio.gd`、`verify_rest_save_repair.gd`、`verify_vehicle_combat.gd` 通过；旧即时检修测试改为启动作业后推进完成，不改变其原来的材料/安全检查。
- `tools/capture_vehicle_services.gd` 图形模式运行并检查 `artifacts/repair_facade_fixed.png`、`repair_kneel.png`、`gas_station_integrated.png`、`fuel_nozzle.png`、`windshield_gap_fixed.png`。
- 验证使用 `GameState.suppress_save=true`，不覆盖玩家存档。部分旧测试退出时仍有已有资源释放提示，功能断言通过；新作业测试正常退出。
- 音频格式/时长及游戏调用已验证；最终声音偏好仍需玩家在实际游戏中试听。尚未在真实手机上实测性能。
