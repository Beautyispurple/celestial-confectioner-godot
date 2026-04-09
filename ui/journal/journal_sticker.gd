class_name JournalSticker
extends Control
## Draggable sticker (star / heart). Clamped to parent page rect by journal_page_surface.

signal pressed_sticker(node: Control)
signal drag_ended

const MIN_SCALE := 0.35
## Was 2.5; +50% headroom for resize handles.
const MAX_SCALE := 3.75

var sticker_id: String = "star"
var _dragging: bool = false
var _drag_armed: bool = false
var _drag_accum: float = 0.0
const DRAG_THRESHOLD_PX := 6.0
var _scale_k: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func setup(id: String, pscale: float, rot: float) -> void:
	sticker_id = id
	_scale_k = clampf(pscale, MIN_SCALE, MAX_SCALE)
	scale = Vector2(_scale_k, _scale_k)
	rotation = rot
	custom_minimum_size = Vector2(48, 48)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_armed = true
				_drag_accum = 0.0
				_dragging = false
				pressed_sticker.emit(self)
			else:
				if _dragging:
					drag_ended.emit()
				_dragging = false
				_drag_armed = false
				_drag_accum = 0.0
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_armed and not _dragging:
			_drag_accum += mm.relative.length()
			if _drag_accum >= DRAG_THRESHOLD_PX:
				_dragging = true
		if _dragging:
			position += mm.relative


func _draw() -> void:
	var ctr := size * 0.5
	var r: float = minf(size.x, size.y) * 0.42
	## Sticker “paper” backing so shapes read clearly on the journal page.
	var back_r: float = minf(size.x, size.y) * 0.48
	draw_circle(ctr, back_r, Color(1, 1, 1, 0.28))
	draw_arc(ctr, back_r, 0.0, TAU, 48, Color(0.45, 0.38, 0.55, 0.55), 2.0, true)
	if sticker_id == "heart":
		_draw_heart_poly(ctr, r, Color(1.0, 0.45, 0.55, 1.0))
	else:
		_draw_star_poly(ctr, r, Color(1.0, 0.85, 0.35, 1.0))


func _draw_star_poly(center: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var a: float = TAU * i / 10.0 - PI * 0.5
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


func _draw_heart_poly(center: Vector2, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = 32
	for i in n:
		var t: float = TAU * float(i) / float(n)
		var x: float = 16.0 * pow(sin(t), 3)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(center + Vector2(x, -y) * (r / 18.0))
	draw_colored_polygon(pts, col)


func get_sticker_scale() -> float:
	return _scale_k


func set_sticker_scale(v: float) -> void:
	_scale_k = clampf(v, MIN_SCALE, MAX_SCALE)
	scale = Vector2(_scale_k, _scale_k)
	queue_redraw()


func pinch_scale(delta: float) -> void:
	set_sticker_scale(_scale_k + delta)


func rotate_by(delta_rad: float) -> void:
	rotation += delta_rad


func serialize() -> Dictionary:
	return {
		"id": sticker_id,
		"pos": [position.x, position.y],
		"scale": _scale_k,
		"rotation": rotation,
	}


static func deserialize(d: Dictionary) -> Dictionary:
	return {
		"id": str(d.get("id", "star")),
		"pos": d.get("pos", [0, 0]),
		"scale": float(d.get("scale", 1.0)),
		"rotation": float(d.get("rotation", 0.0)),
	}
