extends Control
class_name JournalPencilColorButton
## Horizontal pencil-shaped color chip (wood band left, body, ferrule, graphite tip right).

signal color_chosen(index: int)

var color_index: int = 0
var pencil_color: Color = Color.WHITE
var _hover: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw()
	)


func setup(idx: int, col: Color) -> void:
	color_index = idx
	pencil_color = col
	custom_minimum_size = Vector2(168, 48)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			color_chosen.emit(color_index)
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
	draw_rect(Rect2(5.0, body_y, band_w, body_h), Color(0.92, 0.78, 0.55, 1.0))
	draw_rect(Rect2(body_x, body_y, maxf(2.0, body_w - 3.0), body_h), pencil_color)
	draw_rect(Rect2(body_x + body_w - 6.0, body_y, 4.0, body_h), Color(0.75, 0.76, 0.78, 1.0))
	var tip_x: float = body_x + body_w - 2.0
	var mid_y: float = h * 0.5
	var tip_r := Vector2(w - 2.0, mid_y)
	var tip_t := Vector2(tip_x, body_y)
	var tip_b := Vector2(tip_x, body_y + body_h)
	draw_colored_polygon(PackedVector2Array([tip_t, tip_b, tip_r]), Color(0.18, 0.18, 0.2, 1.0))
	draw_rect(Rect2(5.0, body_y, w - 10.0, body_h), Color(0, 0, 0, 0.22), false, 1.5)
	if _hover:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.18), false, 2.0)
