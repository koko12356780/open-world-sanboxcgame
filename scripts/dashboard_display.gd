extends Node2D
## Drawn at native texture resolution, then displayed on the actual dashboard.
var car: CharacterBody3D
var radio: bool = false
var night: bool = false
var indicated_speed: float = 0.0
var indicated_rpm: float = 0.0

func _process(delta: float) -> void:
	indicated_speed = lerpf(indicated_speed,car.speed_kmh,1-exp(-10*delta))
	indicated_rpm = lerpf(indicated_rpm,car.rpm,1-exp(-7*delta))
	night = car.night
	queue_redraw()

func label_at(pos: Vector2, caption: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font,pos,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func gauge(center: Vector2, title: String, max_value: float, value: float, step: int, segments: int = 40) -> void:
	var white := Color("e0e8d8")
	var r := 95.0
	draw_circle(center,r+4,Color("42494a"))
	draw_circle(center,r,Color("080d10"))
	draw_arc(center,r-5,deg_to_rad(135),deg_to_rad(405),100,Color("707973"),1.5,true)
	for i in range(segments+1):
		var angle := deg_to_rad(135 + i*270.0/segments)
		var direction := Vector2(cos(angle),sin(angle))
		var major := i%5 == 0
		var color := Color("cf6c50") if i > segments*0.85 else white
		draw_line(center+direction*(r-7),center+direction*(r-(22 if major else 13)),color,2 if major else 1,true)
		if major:
			var number := "%d" % (i/5*step)
			var text_pos := center+direction*(r-36)-Vector2(number.length()*4, -5)
			label_at(text_pos,number,14,white)
	var needle_angle := deg_to_rad(135+clampf(value/max_value,0,1)*270)
	var tip := Vector2(cos(needle_angle),sin(needle_angle))
	draw_line(center-tip*12,center+tip*72,Color("ed643f"),3,true)
	draw_circle(center,7,Color("596164"))
	label_at(center+Vector2(-27,50),title,13,Color("b9c5b1"))

func _draw() -> void:
	draw_rect(Rect2(0,0,512,256),Color("0b1011"))
	if radio:
		draw_rect(Rect2(12,12,488,232),Color("151b1b"))
		draw_rect(Rect2(28,28,456,88),Color("173c38"))
		label_at(Vector2(48,62),"FM  98.4    /    OPEN STREETS",23,Color("b3d8aa"))
		label_at(Vector2(48,98),"STREET AUDIO     --:--",20,Color("8fbfa0"))
		for i in 6:
			draw_rect(Rect2(36+i*76,140,61,30),Color("333c3b"))
			label_at(Vector2(58+i*76,161),str(i+1),17,Color("b6bfb4"))
		for center in [Vector2(62,211),Vector2(450,211)]:
			draw_circle(center,24,Color("505755"))
			draw_circle(center,18,Color("1a2120"))
		label_at(Vector2(123,218),"VOL         TUNE",17,Color("9eada1"))
		return
	var mph: bool = car.model_index >= 3
	var displayed := indicated_speed/1.609344 if mph else indicated_speed
	gauge(Vector2(128,118),"MPH" if mph else "KM/H",360 if mph else 240,displayed,45 if mph else 30)
	gauge(Vector2(382,118),"RPM x1000",10000,indicated_rpm,1,50)
	draw_rect(Rect2(199,95,113,56),Color("173d35"))
	label_at(Vector2(216,120),"%03d" % int(displayed),26,Color("bbdfaa"))
	label_at(Vector2(268,120),"D%d" % car.gear,18,Color("bbdfaa"))
	label_at(Vector2(218,143),"%.1f KM" % (car.distance/1000),12,Color("a3c89a"))
	label_at(Vector2(210,36),"OPEN STREETS",12,Color("b7c2b0"))
	label_at(Vector2(218,202),"LIGHTS ON" if night else "READY",12,Color("83baa6"))
