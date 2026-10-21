extends CanvasLayer

var new_button: Button
var load_button: Button
var quit_button: Button

func build(main: Node) -> void:
	name="TitleScreen"
	layer=100
	var page:=Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var art:=TextureRect.new()
	art.texture=load("res://assets/ui/title_background.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(art)
	var shade:=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
void fragment(){float a=0.12+0.28*smoothstep(0.58,0.94,UV.y)+0.18*(1.0-smoothstep(0.0,0.30,UV.y));COLOR=vec4(0.025,0.035,0.045,a);}"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	shade.material=material
	page.add_child(shade)
	var title:=Label.new()
	title.text="末日与黎明"
	title.position=Vector2(35,130)
	title.size=Vector2(650,110)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",76)
	title.add_theme_color_override("font_color",Color("fff0d5"))
	title.add_theme_color_override("font_outline_color",Color("172026"))
	title.add_theme_constant_override("outline_size",5)
	page.add_child(title)
	var names:=["新游戏","加载存档","退出游戏"]
	var buttons: Array[Button]=[]
	for i in range(3):
		var button:=Button.new()
		button.text=names[i]
		button.position=Vector2(145,880+i*104)
		button.size=Vector2(430,80)
		button.add_theme_font_size_override("font_size",32)
		main._style_button(button,Color(0.16,0.19,0.21,0.86) if i>0 else Color(0.37,0.27,0.19,0.9))
		page.add_child(button)
		buttons.append(button)
	new_button=buttons[0]
	load_button=buttons[1]
	quit_button=buttons[2]
	new_button.pressed.connect(main._begin_story)
	load_button.disabled=not main.get_node("/root/GameState").has_completed_save()
	load_button.pressed.connect(func():main.save_slots.open("load"))
	quit_button.pressed.connect(func():get_tree().quit())
