# 音乐与音效实装 · 2026-10-18

**最新修订：** 音效重做、车辆前摇和免费现场检修规则见 [2026-10-18 后续记录](audio_revision2.md)，相关旧规则以下仅作历史记录。

## 当前实现

统一入口为自动加载 `scripts/core/audio_director.gd`，由 main 在界面创建完成后 attach。原有玩法、存档结构与影片资源保持原状。

| 场景 | 已接入曲目 | 行为 |
| --- | --- | --- |
| 标题 | Scott Buckley — Signal to Noise | 正常播放，声音面板可调整 |
| 户外/便利店探索 | Signal to Noise — No Piano Melody | 低音量；每 150 秒中保留约 70 秒无配乐间隔，歌曲播放位置仍继续前进 |
| 安静房车、睡眠 | Scott Buckley — Undertow | 场景稳定 2.5 秒再切入，避免反复上下车频繁换曲 |
| 丧尸逼近、围车 | Kevin MacLeod — Lightless Dawn | 有攻击目标的近处敌人或实际攻击触发；威胁消失保留约 6 秒，再恢复普通状态 |
| 开场影片/过场 | 原有影片/序章音频 | 全局音乐即时静音，不覆盖影片原声 |

两播放器交叉淡变，不随每次攻击重新播放；完整歌曲尾端结束后重新播放。它们是完整歌曲，不宣称已制作无缝乐句循环。Hiraeth、Evening Fall 等留在候选清单，本轮未加入，以控制配乐风格与包体。

音乐使用官网免费 MP3，转为 44.1 kHz Ogg Vorbis，四文件合计约 17 MB。三首作品、四个混音版本均按 CC BY 4.0 署名；游戏右上“声音”内可查看作者、来源链接与许可。原始 MP3、哈希、下载地址在 `source/audio`，该目录有 `.gdignore`，不进入运行导入。许可记录在 `licenses/Music_CC_BY_4.0.txt`。

## 已接入音效

- 蛍：硬地/草地/室内脚步、徒手/棒球棍挥空与接触命中、受伤、死亡反馈。
- 丧尸：近处随机低吟、扑咬、受击/倒下、实际接触时拍击车体。
- 房车：启动/熄火、随实际速度调节的引擎循环、急减速提示、实体撞击、两档损坏下的燃烧声；保留已有爆炸声并接入音效音量，远处爆炸有响度衰减。
- 交互：车门/商店门/衣柜、拾取、装备与卸下、货物存取与丢弃、超重拒绝、维修完成、补给任务完成、手动保存结果、按钮点击。
- 生存与环境：缺水/缺食/低油/重伤/车辆危急的首次阈值提醒，风、夜间虫声、湖区水声。正常自动消耗食水不触发拾取音，读档不触发逐件拾取音。

`assets/audio/sfx` 共 70 个短音/变体/循环。39 个来自 Kenney 的 Impact Sounds 和 Interface Sounds，CC0；其余为本项目程序合成的引擎、气声/低吟、挥动、门和环境等初版素材。原始 Kenney 包与映射位于 `source/audio`，原许可分别位于 `licenses/Kenney_Impact_Audio_CC0.txt`、`licenses/Kenney_Interface_Audio_CC0.txt`。这些合成气声不是演员配音，引擎与风水不是实录；后续可保留触发逻辑替换录音素材。

官网来源：

- https://www.scottbuckley.com.au/library/signal-to-noise/
- https://www.scottbuckley.com.au/library/undertow/
- https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1100655
- https://kenney.nl/assets/impact-sounds
- https://kenney.nl/assets/interface-sounds

## 播放约束与设置

世界音效以角色位置为听觉中心，方向跟随镜头。车内与户外位于不同坐标时，将车外拍击声按房车相对方位映射到角色附近并降低音量；不能因为进入独立室内场景而听不到围车。

最多 20 个短世界音同时播放，低吟/拍车/碰撞另有共享冷却，常见动作使用三种变体。脚步按实际位移触发，不在站立或被阻挡时空响；路面与草地按现有道路数据区分。

暂停菜单暂停世界短音并渐停世界循环，UI 反馈仍可用；音乐降音量。音乐淡变和威胁声音冷却用真实时间，不随睡眠 30 倍推进而加速。睡眠不播放脚步或高频生存提醒，车辆受袭仍按实际攻击发声。影片、失败和读档转换处理独立。

“声音”面板有音乐、动作车辆、环境、界面提醒及影片原声五类音量；保存到独立 `user://audio_settings.cfg`，不修改六槽游戏进度。面板保留进入前暂停状态，支持返回按钮和 Esc。

## 重建与验证

素材重建顺序：

1. `tools/prepare_game_music.py`：从官网取得/续传原 MP3、校验文件长度、转换 Ogg。已下载原文件保留，可离线重新转换。
2. `tools/build_game_sfx.py`：生成 70 个合成基础音。
3. `tools/prepare_kenney_sfx.py`：从已保存的两个 Kenney 压缩包覆盖 39 个录制音，保存原许可及映射。第二步会覆盖这些文件，因此务必随后执行第三步。
4. Godot 编辑器导入更新素材。

验证：Godot 编辑器导入；完整首日 smoke；`verify_rest_save_repair.gd`、`verify_vehicle_combat.gd`、`verify_day_survival.gd`；新增图形模式 `verify_audio.gd` 检查四种音乐状态、挥空/命中分别触发、车内围车声音映射、暂停反馈、影片独占配乐，并录制实际音频输出排除空声道。`capture_audio.gd` 可独立截取设置页。

产物：`artifacts/audio_settings.png`、`artifacts/audio_title_sample.wav`。这些检查不覆盖用户游戏进度。自动检查确认触发和输出，不等同于人工听感验收；手机扬声器上的动态、引擎质感和群体低吟仍适合下一轮实际游玩调整。
