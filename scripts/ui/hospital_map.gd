extends Control
var hospital
func _ready():
 position=Vector2(480,64);size=Vector2(220,235);mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta):
 visible=is_instance_valid(hospital) and hospital.active and not hospital.main.dialog_panel.visible
 if visible:queue_redraw()
func point(v: Vector2)->Vector2:return Vector2(110,125)+v*5.4
func _draw():
 if not is_instance_valid(hospital):return
 draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
 var font=ThemeDB.fallback_font
 draw_string(font,Vector2(12,24),"医院 · %dF"%(hospital.floor_index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("f5edce"))
 var rects=hospital.MAIN_RECTS.duplicate()
 if hospital.floor_index==0:rects.append(hospital.ANNEX)
 for rect in rects:draw_rect(Rect2(point(rect.position),rect.size*5.4),Color("788b87"))
 for data in hospital.rooms:
  if data.floor!=hospital.floor_index:continue
  draw_rect(Rect2(point(data.rect.position),data.rect.size*5.4),Color("c7cebd"),false,1.0)
  var caption=str(data.name).split(" ")[0]
  if not caption.is_valid_int():caption={"医师办公室":"办公","诊室 01":"诊1","诊室 02":"诊2","采样室":"采样","检验室":"检验","手术室":"手术","太平间":"太平","术前准备 / 术后观察":"准备","准备 / 转运":"转运","器械 / 布草储藏":"储藏","卫生间":"卫生","卫生 / 清洁间":"卫生","清洁 / 污物间":"清洁"}.get(data.name,"配套")
  draw_string(font,point(data.rect.get_center())+Vector2(-10,3),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("ebefdf"))
 draw_rect(Rect2(point(hospital.STAIR.position),hospital.STAIR.size*5.4),Color("d5b85f"),false,1.5)
 var p=hospital.to_interior_local(hospital.main.hotaru.global_position)
 draw_circle(point(Vector2(p.x,p.z)),4,Color("ffde79"))
 var forward=Vector2(sin(hospital.yaw),cos(hospital.yaw))
 draw_line(point(Vector2(p.x,p.z)),point(Vector2(p.x,p.z))+forward*9,Color("ffde79"),2)
 draw_string(font,Vector2(12,226),"黄点：小萤   左上：楼梯",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e2eadb"))
func _panel():
 var style=StyleBoxFlat.new();style.bg_color=Color("1c3039e8");style.border_color=Color("869f95");style.set_border_width_all(2);style.set_corner_radius_all(12);return style
