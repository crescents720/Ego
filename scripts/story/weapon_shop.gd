extends CanvasLayer
const SHOP_CENTER:=Vector3(112,.08,154)
# Set from the converted asset's actual metal-door center.
var door:=Vector3(107.8,.95,153.8)
var main
var model: Node3D
var veil: Control
var portrait: TextureRect
var speaker: Label
var words: Label
var next_button: Button
var accept: Button
var decline: Button
var wallet: Label
var merchant_view: SubViewport
var lines: Array=[]
var index:=0
var active:=false
var _before_pause:=false
var _choice_pending:=false
func build(owner_main) -> void:
 main=owner_main
 layer=48
 process_mode=Node.PROCESS_MODE_ALWAYS
 main.town_layout._road(Vector2(75,154),Vector2(107.8,154),7.0)
 model=load("res://assets/weapon_shop/gun_shop.glb").instantiate()
 model.position=SHOP_CENTER
 model.rotation.y=-PI/2
 main.world_root.add_child(model)
 main.town_occlusion.register_building(model)
 var body:=StaticBody3D.new()
 body.collision_layer=3
 var shape:=BoxShape3D.new()
 shape.size=Vector3(7.2,4.3,6.8)
 var col:=CollisionShape3D.new()
 col.shape=shape
 body.position=SHOP_CENTER+Vector3(.65,2.1,0)
 body.add_child(col)
 main.world_root.add_child(body)
 main._add_label("神秘武器店 · 正门 E 进入",door+Vector3(0,2.2,0),Color("ecd49a"),30)
 veil=Control.new()
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(veil)
 var background:=TextureRect.new()
 background.texture=load("res://assets/weapon_shop/interior.png")
 background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 veil.add_child(background)
 var top:=ColorRect.new()
 top.color=Color(0,.02,.03,.7)
 top.size=Vector2(720,80)
 veil.add_child(top)
 wallet=Label.new()
 wallet.position=Vector2(30,25)
 wallet.add_theme_font_size_override("font_size",25)
 veil.add_child(wallet)
 portrait=TextureRect.new()
 portrait.position=Vector2(100,240)
 portrait.size=Vector2(520,640)
 portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
 veil.add_child(portrait)
 _build_merchant_portrait()
 var panel:=Panel.new()
 panel.position=Vector2(22,845)
 panel.size=Vector2(676,405)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color(.04,.075,.08,.95)
 style.border_color=Color("aa9270")
 style.set_border_width_all(2)
 style.set_corner_radius_all(16)
 panel.add_theme_stylebox_override("panel",style)
 veil.add_child(panel)
 speaker=Label.new()
 speaker.position=Vector2(27,20)
 speaker.add_theme_font_size_override("font_size",30)
 speaker.add_theme_color_override("font_color",Color("efcf91"))
 panel.add_child(speaker)
 words=Label.new()
 words.position=Vector2(27,75)
 words.size=Vector2(620,205)
 words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 words.add_theme_font_size_override("font_size",26)
 panel.add_child(words)
 next_button=_button("继续  ›",Vector2(440,306),Vector2(205,66),advance,panel)
 accept=_button("支付 1000 元",Vector2(25,306),Vector2(300,66),purchase,panel)
 decline=_button("先离开",Vector2(345,306),Vector2(300,66),leave,panel)
 veil.hide()
func _button(text_value: String,p: Vector2,dimensions: Vector2,action: Callable,parent: Node) -> Button:
 var b:=Button.new()
 b.text=text_value
 b.position=p
 b.size=dimensions
 main._style_button(b,Color("4b4940"))
 parent.add_child(b)
 b.pressed.connect(action)
 return b
func _build_merchant_portrait() -> void:
 merchant_view=SubViewport.new()
 merchant_view.size=Vector2i(520,640)
 merchant_view.transparent_bg=true
 merchant_view.own_world_3d=true
 merchant_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 add_child(merchant_view)
 var stage:=Node3D.new()
 merchant_view.add_child(stage)
 var merchant: Node3D=load("res://assets/weapon_shop/merchant.glb").instantiate()
 stage.add_child(merchant)
 var cam:=Camera3D.new()
 cam.position=Vector3(0,1.25,2.7)
 stage.add_child(cam)
 cam.look_at(Vector3(0,1.22,0))
 cam.projection=Camera3D.PROJECTION_ORTHOGONAL
 cam.size=1.45
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-25,-25,0)
 light.light_energy=1.4
 stage.add_child(light)
 var environment:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color(0,0,0,0)
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("9aafbf")
 env.ambient_light_energy=.7
 environment.environment=env
 stage.add_child(environment)
func nearby() -> bool:
 return not main.inside_rv and not main.inside_store and not main.in_vehicle and main.trolley.near_door(door,2.4)
func enter() -> void:
 if active or not nearby() or main.trolley.loading:return
 main.trolley.release()
 _before_pause=get_tree().paused
 active=true
 main.mobile_joystick.reset()
 main.hotaru.set_active(false)
 main.controls_enabled=false
 var first_visit: bool=not GameState.weapon_shop_visited
 GameState.weapon_shop_visited=true
 _choice_pending=false
 if GameState.weapon_bought:
  lines=[["神秘店员","钱货两清，小姑娘。推车可别弄丢了……下回有好东西，我还会给你留着。"]]
 else:
  lines=[["小萤","打、打扰了……有人吗？"],["神秘店员","呵呵……活人？这年头，这可比子弹还稀罕。"],["小萤","呀！你……你没有变成丧尸？对不起，我以为这里已经……"],["神秘店员","以为我是死人？小姑娘，死人可不会做生意。别发抖，我只认钱。"],["神秘店员","柜台上这把 M60，是能让那些东西乖乖闭嘴的好货。再送你五百发弹药。只要一千元，童叟无欺。"],["小萤","一、一千……能让我安全地找到哥哥吗？"]]
  if not first_visit:lines=[["神秘店员","又是你。M60，五百发弹药，一千元。钱带够了吗？"]]
  _choice_pending=true
 index=0
 veil.show()
 merchant_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 get_tree().paused=true
 show_line()
func show_line() -> void:
 wallet.text="神秘武器店                         现金  ¥ %d"%GameState.cash
 var line: Array=lines[index]
 speaker.text=line[0]
 words.text=line[1]
 portrait.texture=merchant_view.get_texture() if line[0]=="神秘店员" else load("res://assets/ui/hotaru_equipment.png")
 next_button.show()
 accept.hide()
 decline.hide()
func advance() -> void:
 index+=1
 if index<lines.size():show_line();return
 if _choice_pending:
  _choice_pending=false
  if GameState.cash<1000:
   lines=[["神秘店员","连一千块都拿不出来？那还站在这儿做什么！去外头找钱，别耽误我做生意。"],["小萤","对、对不起……我这就走。"]]
   index=0
   show_line()
  else:
   speaker.text="神秘店员"
   portrait.texture=merchant_view.get_texture()
   words.text="一千元，M60 加五百发弹药。买下它，还是空着手回到街上？"
   next_button.hide()
   accept.show()
   decline.show()
  return
 leave()
func purchase() -> void:
 if not GameState.buy_m60():
  main.rest_notice("现金不足，或已经完成过这笔交易。")
  leave()
  return
 GameState.cart_position=door+Vector3(-1.4,-.87,1.4)
 GameState.cart_yaw=-PI/2
 lines=[["小萤","呜……好重！我、我抬不起来……"],["神秘店员","二十三公斤。你以为这是玩具？呵呵，别用那种眼神看我。"],["神秘店员","算我大发慈悲，再白送你一辆推车。枪和弹药都装好了，合计二十五公斤。自己推回房车去。"],["小萤","谢、谢谢……我会小心的。"],["神秘店员","推着它可腾不出手打架。遇上麻烦，就先松手。命没了，钱可不退。"]]
 index=0
 show_line()
func leave() -> void:
 active=false
 veil.hide()
 merchant_view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 get_tree().paused=_before_pause
 main.controls_enabled=true
 main.hotaru.set_active(true)
 main.rest_notice("靠近推车按交互推行；运到房车右侧门再上车，会搬运货物并收起推车。" if GameState.weapon_bought and GameState.cart_deployed else "武器店：1000 元可购买 M60 与 500 发弹药。")
