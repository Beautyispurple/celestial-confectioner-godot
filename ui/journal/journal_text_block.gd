extends Control
class_name JournalTextBlock
## Placed journal text: plain when idle, frame when selected; drag to reposition.

signal pressed_block(block: JournalTextBlock)
signal drag_ended_block(block: JournalTextBlock)

const FONT_SZ := 18
const PAD := 4.0

var max_line_width: float = 200.0
var block_selected: bool = false:
	set(v):
		block_selected = v
		queue_redraw()

var _lbl: Label
var _drag_armed: bool = false
var _dragging: bool = false
var _drag_accum: float = 0.0
const DRAG_THRESHOLD_PX := 6.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_label()


func _ensure_label() -> void:
	if _lbl != null:
		return
	_lbl = Label.new()
	_lbl.name = "Label"
	add_child(_lbl)
	_lbl.add_theme_font_size_override("font_size", FONT_SZ)
	_lbl.add_theme_color_override("font_color", Color(0.12, 0.1, 0.18, 1.0))
	_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lbl.position = Vector2(PAD, PAD)


func setup(txt: String, max_w: float, local_pos: Vector2) -> void:
	_ensure_label()
	max_line_width = max_w
	_lbl.text = txt
	_lbl.custom_minimum_size.x = max_w
	_lbl.size.x = max_w
	var msz: Vector2 = _lbl.get_minimum_size()
	custom_minimum_size = Vector2(max_w + PAD * 2, msz.y + PAD * 2)
	size = custom_minimum_size
	_lbl.size = Vector2(max_w, msz.y)
	position = local_pos
	queue_redraw()


func get_block_text() -> String:
	return _lbl.text if _lbl != null else ""


func set_selected(on: bool) -> void:
	block_selected = on


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_armed = true
				_drag_accum = 0.0
				_dragging = false
				pressed_block.emit(self)
			else:
				if _dragging:
					drag_ended_block.emit(self)
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
	if block_selected:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.22, 0.48, 0.88, 0.95), false, 2.0)
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(0.22, 0.48, 0.88, 0.28), false, 1.0)


func serialize_dict() -> Dictionary:
	return {"text": get_block_text(), "pos": [position.x, position.y], "max_w": max_line_width}


static func from_save_dict(d: Dictionary) -> Dictionary:
	return {
		"text": str(d.get("text", "")),
		"pos": d.get("pos", [0, 0]),
		"max_w": float(d.get("max_w", 200.0)),
	}
