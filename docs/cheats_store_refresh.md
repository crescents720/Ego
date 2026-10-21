# 2026-10-19：作弊码与便利店持续供货

## 使用

电脑局内按 Enter/小键盘 Enter，或点击右上角齿轮；手机点齿轮。菜单暂停世界并清空摇杆/方向输入，输入 `showmethemoney`，按回车或“确认作弊码”，每次增加 10,000 现金，可重复使用。无效代码不加钱。返回游戏或 Esc 关闭，恢复时间与操作。仅局内正常控制时开放，不覆盖影片/商店对话或其他暂停菜单。菜单放在上半屏，便于手机软键盘输入。金额使用原现金存档字段。

便利店所有货架可反复拿取，包含食物、饮水、医疗用品和材料。食物/饮水数量界面显示“货架持续供货 · 随时可取”，不再消耗库存；单次可取数量仍受10kg背包或附近25kg推车容量限制。旧存档 `store_looted` 继续记录访问历史，但不再隐藏货架；`store_stock` 仅为旧档兼容字段，不再影响供货。

店内初始2只，之后每180秒世界时间（半个游戏日）补充随机1～2只，存活总数最多6。击杀后不立即补充；白天黑夜都按同一上限，睡眠快进也推进刷新。远处按逻辑人数计时，进入时生成对应数量；店内新增怪物选空闲过道，并至少距离玩家2.5m。已存在的室内丧尸仍在离店后隐藏停用。人数和下一刷新边界保存到存档，读旧档使用默认值再按世界时间补算，长时间快进也不会囤积超过6只的刷新欠账。

## 实现/验证

- `scripts/ui/test_settings.gd`：局内齿轮与作弊码界面，独立手指按钮路由接入 `mobile_joystick.gd`。
- `GameState.apply_cheat`、`take_stock`；新增 survival 字段 `store_residents` / `store_next_refresh`，保持schema5兼容。
- `convenience_store.gd`：访问历史不再影响货架可取状态。
- `zombie_population.gd`：按世界时间补充逻辑人数，按空闲位置物化，死亡同步减少人数。
- `verify_cheat_store_refresh.gd`：实际回车输入与提交、重复/错误代码、移动时第二指点齿轮、旧库存为零仍多轮取货/重量限制、可重复货架、半日节点、刷新上限、击杀不立刻补回、后续补充及隔离存档往返。
- 回归 `verify_mobile_input_store`、`verify_cart_mobility`、`verify_day_survival`、`verify_cargo_input` 通过。后两项已把旧的“库存扣减”断言改成持续供货语义。
- 图形检查 `capture_cheat_store.gd`，截图 `artifacts/cheat_settings.png`、`settings_gear_hud.png`、`infinite_store_supply.png`。
- 测试存档位于独立 `user://testing_store_revision/test.cfg`，未改玩家槽位。

安卓包：`builds/android/FireflyRoad-0.1.20261019.4-arm64-debug.apk`，code4，同包名同签名覆盖安装保留存档。完整SHA及安装验证见构建信息与后续记录。


安卓API37模拟器已实际安装：读取旧耗尽货架测试档，点右上齿轮，通过系统输入事件输入代码并回车，确认0→10000。随后进入便利店，在饮水货架成功取一桶，再次打开同一货架，显示可继续拿取及下一桶负重10/10kg。截图 `artifacts/android_settings_cheat.png`、`android_settings_supply.png`、`android_settings_supply_repeat.png`。日志无脚本/崩溃错误；尚未连接真机。最终包修正了混合文字中的冒号缺字显示，签名v2/v3与16KB对齐验证通过，同revision3签名。测试均在独立只读模拟器和隔离存档中进行，玩家电脑/手机存档未改。
