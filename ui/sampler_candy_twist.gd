extends Control
## Triangular candy-wrapper end cap; point faces inward toward the label band.

@export var point_right: bool = false


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 1.0 or h < 1.0:
		return
	var fill := Color(0.12, 0.1, 0.16, 1.0)
	var outline := Color(1.0, 0.82, 0.94, 0.5)
	var pts: PackedVector2Array
	if point_right:
		pts = PackedVector2Array([Vector2(0, 0), Vector2(0, h), Vector2(w, h * 0.5)])
	else:
		pts = PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(0, h * 0.5)])
	draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.25, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
