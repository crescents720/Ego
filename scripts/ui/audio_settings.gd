extends CanvasLayer
var main
var launch: Button
var veil: ColorRect
var panel: VBoxContainer
var was_paused := false
func build(owner_main) -> void:
 main=owner_main
 layer=120
 process_mode=Node.PROCESS_MODE_ALWAYS
 launch=Button.new()
 launch.text="声音"
 launch.position=Vector2(594,20)
 launch.size=Vector2(100,48)
 main._style_button(launch,Color("35434b"))
 add_child(launch)
 launch.pressed.connect(open)
 veil=ColorRect.new()
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 veil.color=Color(.02,.035,.045,.96)
 add_child(veil)
 panel=VBoxContainer.new()
 panel.position=Vector2(55,110)
 panel.size=Vector2(610,1020)
 panel.add_theme_constant_override("separation",18)
 veil.add_child(panel)
 var title:=Label.new()
 title.text="声音设置与音乐署名"
 title.add_theme_font_size_override("font_size",30)
 panel.add_child(title)
 var labels:={"Music":"背景音乐","Effects":"动作与车辆","Ambience":"环境氛围","UI":"界面与提醒","Film":"影片原声"}
 for bus in labels:
  var caption:=Label.new()
  caption.text=labels[bus]
  panel.add_child(caption)
  var slider:=HSlider.new()
  slider.custom_minimum_size=Vector2(580,44)
  slider.min_value=0
  slider.max_value=1
  slider.step=.01
  slider.value=AudioDirector.volumes[bus]
  slider.value_changed.connect(func(value):AudioDirector.apply_volume(bus,value))
  panel.add_child(slider)
 var credits:=RichTextLabel.new()
 credits.custom_minimum_size=Vector2(600,300)
 credits.add_theme_font_size_override("normal_font_size",19)
 credits.bbcode_enabled=true
 credits.text="[b]音乐 · CC BY 4.0[/b]\nSignal to Noise（含 No Piano Melody）\nUndertow\nby Scott Buckley — www.scottbuckley.com.au\n\nLightless Dawn\nby Kevin MacLeod — incompetech.com\n\n许可：https://creativecommons.org/licenses/by/4.0/\n处理：转为 Ogg；运行时淡入淡出。\n小萤配音：あみたろの声素材工房\n[url=https://amitaro.net/]https://amitaro.net/[/url]（免费署名许可）\n拟音：artisticdude、Independent.nu、\nGboxMikeFozzy、Fantozzi、looneybits、\nJoseph SARDIN / BigSoundBank（CC0）。\n引擎循环：qubodup（CC BY 3.0）。\nhttps://creativecommons.org/licenses/by/3.0/\nhttps://opengameart.org/content/car-engine-loop-96khz-4s\n处理：剪辑、滤波、混音与格式转换。\n其余音效：Kenney（CC0）与本项目素材。\n\n[url=https://www.scottbuckley.com.au/library/signal-to-noise/]Signal to Noise 来源[/url] · [url=https://www.scottbuckley.com.au/library/undertow/]Undertow 来源[/url]\n[url=https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100655]Lightless Dawn 来源[/url]"
 credits.text+="\n机枪音效：Light Machine Gun — KuraiWolf（CC BY 4.0）\nhttps://opengameart.org/content/light-machine-gun\n剪辑、淡出、单声道转换。"
 credits.meta_clicked.connect(func(url):OS.shell_open(str(url)))
 panel.add_child(credits)
 var close_button:=Button.new()
 close_button.text="返回游戏"
 close_button.custom_minimum_size=Vector2(580,64)
 main._style_button(close_button,Color("36524e"))
 panel.add_child(close_button)
 close_button.pressed.connect(close)
 veil.hide()
func open() -> void:
 was_paused=get_tree().paused
 veil.show()
 get_tree().paused=true
 AudioDirector.ui()
func close() -> void:
 veil.hide()
 get_tree().paused=was_paused
 AudioDirector.ui()

func _unhandled_key_input(event: InputEvent) -> void:
 if veil.visible and event.is_action_pressed("ui_cancel"):
  close()
  get_viewport().set_input_as_handled()
