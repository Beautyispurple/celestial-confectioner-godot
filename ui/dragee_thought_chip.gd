class_name DrageeThoughtChip
extends Control
## Round “candy” chip with optional horizontal marquee; tap (shelf) or drag (disposal).

signal activated
signal drag_started
signal drag_ended(global_pos: Vector2)

const _CLIP_INSET := 3
const _LABEL_PAD := 4

@export var draggable: bool = false

var disabled: bool = false
var _placeholder_style: bool = false

var _clip: Control
var _bg_panel: Panel
var _label: Label
var _marquee_tween: Tween
var _thought_text: String = ""

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _saved_parent: Node
var _saved_position: Vector2 = Vector2.ZERO

## When `draggable`, scales label from `min(size.x,size.y)` (defaults match original disposal chips).
var _draggable_font_scale: float = 0.13
var _draggable_font_min: int = 13
var _draggable_font_max: int = 26

var _tap_pressing: bool = false
var _tap_start: Vector2 = Vector2.ZERO
var _tap_moved: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_ensure_ui()
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	call_deferred("_on_resized")


func _ensure_ui() -> void:
	if _clip != null:
		return
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.offset_left = _CLIP_INSET
	_clip.offset_top = _CLIP_INSET
	_clip.offset_right = -_CLIP_INSET
	_clip.offset_bottom = -_CLIP_INSET
	add_child(_clip)

	_bg_panel = Panel.new()
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip.add_child(_bg_panel)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.clip_contents = false
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.98, 1))
	_clip.add_child(_label)
	_apply_draggable_label_mode()


func _on_mouse_entered() -> void:
	if disabled or draggable:
		return
	modulate = Color(1.06, 1.04, 1.08, 1.0)


func _on_mouse_exited() -> void:
	if disabled:
		return
	if _placeholder_style:
		modulate = Color(0.45, 0.4, 0.5, 0.55)
	else:
		modulate = Color.WHITE


func _on_resized() -> void:
	_apply_corner_radius()
	call_deferred("_layout_label_and_marquee")


func _apply_corner_radius() -> void:
	if _bg_panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.34, 0.62, 1.0)
	sb.border_color = Color(1, 0.82, 0.94, 0.55)
	var side := mini(int(size.x), int(size.y))
	sb.set_border_width_all(maxi(2, side / 36))
	sb.set_corner_radius_all(maxi(side / 2, 1))
	_bg_panel.add_theme_stylebox_override("panel", sb)


func set_thought_text(t: String) -> void:
	_placeholder_style = false
	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_thought_text = t
	if _label:
		_label.text = t
	_apply_draggable_label_mode()
	modulate = Color.WHITE
	call_deferred("_layout_label_and_marquee")


func set_placeholder_empty() -> void:
	_placeholder_style = true
	disabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thought_text = "—"
	if _label:
		_label.text = "—"
	modulate = Color(0.45, 0.4, 0.5, 0.55)
	call_deferred("_layout_label_and_marquee")


func set_draggable_font_range(scale: float, min_fs: int, max_fs: int) -> void:
	_draggable_font_scale = scale
	_draggable_font_min = min_fs
	_draggable_font_max = max_fs
	if _label != null and draggable:
		_refresh_draggable_font_size()
		call_deferred("_layout_label_and_marquee")


func remember_scatter_slot(parent: Node, pos: Vector2) -> void:
	_saved_parent = parent
	_saved_position = pos


func reparent_for_drag(new_parent: Node) -> void:
	if get_parent() == new_parent:
		return
	var gp := get_global_position()
	reparent(new_parent)
	global_position = gp


func restore_scatter_slot() -> void:
	if _saved_parent == null or not is_instance_valid(_saved_parent):
		return
	reparent(_saved_parent)
	position = _saved_position


func _apply_draggable_label_mode() -> void:
	if _label == null:
		return
	if draggable:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_refresh_draggable_font_size()
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label.add_theme_font_size_override("font_size", 11)


func _refresh_draggable_font_size() -> void:
	if not draggable or _label == null:
		return
	var side := minf(size.x, size.y)
	var fs: int = clampi(int(side * _draggable_font_scale), _draggable_font_min, _draggable_font_max)
	_label.add_theme_font_size_override("font_size", fs)


func _layout_label_and_marquee() -> void:
	_kill_marquee()
	if _label == null or _clip == null:
		return
	if draggable:
		await get_tree().process_frame
		if not is_instance_valid(_label):
			return
		_refresh_draggable_font_size()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.offset_left = _LABEL_PAD
		_label.offset_top = _LABEL_PAD
		_label.offset_right = -_LABEL_PAD
		_label.offset_bottom = -_LABEL_PAD
		return
	var avail: float = _clip.size.x - _LABEL_PAD * 2.0
	if avail < 4.0:
		return
	await get_tree().process_frame
	if not is_instance_valid(_label):
		return
	var text_w: float = _label.get_minimum_size().x
	var h: float = _clip.size.y
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.position = Vector2(_LABEL_PAD, 0)
	_label.size = Vector2(maxf(text_w, avail), h)
	if text_w > avail + 1.0:
		_start_marquee(text_w, avail)


func _start_marquee(text_w: float, avail: float) -> void:
	var travel: float = text_w - avail + 12.0
	_marquee_tween = create_tween()
	_marquee_tween.set_loops()
	_label.position.x = _LABEL_PAD
	_marquee_tween.tween_property(_label, "position:x", _LABEL_PAD - travel, 2.4).set_ease(
		Tween.EASE_IN_OUT
	)
	_marquee_tween.tween_interval(0.35)
	_marquee_tween.tween_property(_label, "position:x", _LABEL_PAD, 2.4).set_ease(
		Tween.EASE_IN_OUT
	)
	_marquee_tween.tween_interval(0.35)


func _kill_marquee() -> void:
	if _marquee_tween != null and is_instance_valid(_marquee_tween):
		_marquee_tween.kill()
	_marquee_tween = null


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if draggable:
		_handle_drag(event)
		return
	_handle_tap(event)


func _handle_tap(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_tap_pressing = true
				_tap_start = mb.position
				_tap_moved = false
			else:
				if _tap_pressing and not _tap_moved:
					activated.emit()
				_tap_pressing = false
			accept_event()
	elif event is InputEventMouseMotion and _tap_pressing:
		if _tap_start.distance_to(event.position) > 6.0:
			_tap_moved = true


func _handle_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				drag_started.emit()
			else:
				if _dragging:
					_dragging = false
					drag_ended.emit(get_global_mouse_position())
			accept_event()
	elif event is InputEventMouseMotion:
		if _dragging:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_dragging = false
				drag_ended.emit(get_global_mouse_position())
			else:
				global_position = get_global_mouse_position() - _drag_offset
			accept_event()
