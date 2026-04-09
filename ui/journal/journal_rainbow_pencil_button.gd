extends Control
class_name JournalRainbowPencilButton
## Horizontal rainbow pencil chip; toggle to enable rainbow stroke.

signal rainbow_toggled(on: bool)

var _on: bool = false
var _hover: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(168, 48)
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw()
	)


func set_rainbow(on: bool) -> void:
	_on = on
	queue_redraw()


func is_rainbow_on() -> bool:
	return _on


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on = not _on
			rainbow_toggled.emit(_on)
			queue_redraw()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var body_h: float = h * 0.82
	var body_y: float = (h - body_h) * 0.5
	var tip_w: float = w * 0.13
	var band_w: float = w * 0.1
	var body_x: float = 5.0 + band_w
	var body_w: float = w - body_x - tip_w - 7.0
	# Wood band (left)
	draw_rect(Rect2(5.0, body_y, band_w, body_h), Color(0.92, 0.78, 0.55, 1.0))
	# Rainbow body (stripes)
	var segs: int = 7
	for i in segs:
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var col := Color.from_hsv(t0, 0.65, 0.95, 1.0)
		var x0: float = body_x + t0 * body_w
		var x1: float = body_x + t1 * body_w
		draw_rect(Rect2(x0, body_y, maxf(1.0, x1 - x0), body_h), col)
	# Ferrule
	draw_rect(Rect2(body_x + body_w - 6.0, body_y, 4.0, body_h), Color(0.75, 0.76, 0.78, 1.0))
	# Tip (triangle right)
	var tip_x: float = body_x + body_w + 1.0
	var mid_y: float = h * 0.5
	var tip_r := Vector2(w - 2.0, mid_y)
	var tip_t := Vector2(tip_x, body_y)
	var tip_b := Vector2(tip_x, body_y + body_h)
	draw_colored_polygon(PackedVector2Array([tip_t, tip_b, tip_r]), Color(0.18, 0.18, 0.2, 1.0))
	draw_rect(Rect2(5.0, body_y, w - 10.0, body_h), Color(0, 0, 0, 0.2), false, 1.5)
	if _on:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.85, 0.45, 0.35), false, 2.5)
	if _hover:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12), false, 2.0)
