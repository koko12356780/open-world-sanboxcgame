extends Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(w*0.16,0),Vector2(w*0.58,h),Vector2(w*0.36,h)]),Color(0,0,0,0.94))
	draw_rect(Rect2(0,0,w,h),Color(0.005,0.015,0.04,0.16))
