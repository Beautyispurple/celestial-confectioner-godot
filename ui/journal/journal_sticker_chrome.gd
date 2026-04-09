extends Control
class_name JournalStickerChrome
## Selection frame around a sticker: corner resize + trash. Root ignores mouse; handles are STOP.

const HANDLE := 22.0
const TRASH_R := 15.0
const MARGIN := 6.0
const ROTATE_HIT := 40.0

var target: JournalSticker = null
var page: JournalPageSurface

var _resize_corner: int = -1
var _start_mouse_global: Vector2
var _start_scale: float
var _start_dist: float

var _rotating: bool = false
var _rotate_pivot_global: Vector2 = Vector2.ZERO
var _start_rot: float = 0.0
var _start_pointer_angle: float = 0.0

var _handles: Array[Control] = []
var _rotate_zone: Control
var _trash_btn: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	set_process(true)
	for i in 4:
		var h := Control.new()
		h.custom_minimum_size = Vector2(HANDLE, HANDLE)
		h.size = Vector2(HANDLE, HANDLE)
		h.mouse_filter = Control.MOUSE_FILTER_STOP
		h.z_index = 400
		var corner_idx: int = i
		h.gui_input.connect(func(ev: InputEvent) -> void: _on_handle_gui(corner_idx, ev))
		add_child(h)
		_handles.append(h)
	_rotate_zone = Control.new()
	_rotate_zone.custom_minimum_size = Vector2(ROTATE_HIT, ROTATE_HIT)
	_rotate_zone.size = Vector2(ROTATE_HIT, ROTATE_HIT)
	_rotate_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate_zone.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_rotate_zone.z_index = 350
	_rotate_zone.gui_input.connect(_on_rotate_gui)
	add_child(_rotate_zone)
	_trash_btn = Button.new()
	_trash_btn.flat = true
	_trash_btn.focus_mode = Control.FOCUS_NONE
	_trash_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_trash_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_trash_btn.z_index = 280
	var es := StyleBoxEmpty.new()
	_trash_btn.add_theme_stylebox_override("normal", es)
	_trash_btn.add_theme_stylebox_override("pressed", es.duplicate())
	_trash_btn.add_theme_stylebox_override("hover", es.duplicate())
	_trash_btn.text = ""
	_trash_btn.custom_minimum_size = Vector2(44.0, 44.0)
	_trash_btn.size = Vector2(44.0, 44.0)
	_trash_btn.pressed.connect(_on_trash_pressed)
	add_child(_trash_btn)


func attach_to(st: JournalSticker, p: JournalPageSurface) -> void:
	target = st
	page = p
	visible = st != null and is_instance_valid(st)
	_resize_corner = -1
	_rotating = false
	queue_redraw()


func detach() -> void:
	target = null
	visible = false
	_resize_corner = -1
	_rotating = false
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible or target == null or not is_instance_valid(target):
		return
	var gr := target.get_global_rect()
	var xf: Transform2D = get_parent().get_global_transform().affine_inverse()
	var pts: Array[Vector2] = [
		gr.position,
		Vector2(gr.end.x, gr.position.y),
		gr.end,
		Vector2(gr.position.x, gr.end.y),
	]
	var r := Rect2(xf * pts[0], Vector2.ZERO)
	for i in range(1, 4):
		r = r.expand(xf * pts[i])
	position = r.position - Vector2(MARGIN, MARGIN)
	size = r.size + Vector2(MARGIN * 2, MARGIN * 2)
	# Layout handles: TL, TR, BR, BL (Control.size must be set each frame — min size alone leaves 0×0 hits).
	var hsz := Vector2(HANDLE, HANDLE)
	for hi in _handles:
		hi.size = hsz
	_handles[0].position = Vector2.ZERO
	_handles[1].position = Vector2(size.x - HANDLE, 0)
	_handles[2].position = Vector2(size.x - HANDLE, size.y - HANDLE)
	_handles[3].position = Vector2(0, size.y - HANDLE)
	var rz := Vector2(ROTATE_HIT, ROTATE_HIT)
	_rotate_zone.size = rz
	_rotate_zone.position = Vector2((size.x - ROTATE_HIT) * 0.5, size.y - ROTATE_HIT)
	## Trash hitbox centered on the drawn circle.
	var tc := Vector2(size.x * 0.5, HANDLE + TRASH_R + 6.0)
	var trash_side: float = TRASH_R * 2.0 + 18.0
	_trash_btn.size = Vector2(trash_side, trash_side)
	_trash_btn.position = tc - _trash_btn.size * 0.5
	queue_redraw()


func _draw() -> void:
	if not visible or target == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.55, 0.95, 0.4), false, 2.0)
	# Handle fills (visual; hit is child controls)
	for h in _handles:
		draw_rect(Rect2(h.position, h.size), Color(0.95, 0.95, 1.0, 0.95))
		draw_rect(Rect2(h.position, h.size), Color(0.2, 0.45, 0.9, 1.0), false, 1.5)
	## Top-center, below the corner handle row so delete vs resize don’t fight.
	var tc := Vector2(size.x * 0.5, HANDLE + TRASH_R + 6.0)
	draw_circle(tc, TRASH_R, Color(0.92, 0.18, 0.22, 1.0))
	draw_arc(tc, TRASH_R - 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.85), 2.0, true)
	var x0 := tc + Vector2(-6.0, -6.0)
	var x1 := tc + Vector2(6.0, 6.0)
	draw_line(x0, x1, Color.WHITE, 2.5, true)
	draw_line(Vector2(x1.x, x0.y), Vector2(x0.x, x1.y), Color.WHITE, 2.5, true)
	## Rotate nub (hit target is _rotate_zone)
	var rc: Vector2 = _rotate_zone.position + _rotate_zone.custom_minimum_size * 0.5
	draw_arc(rc, 7.0, PI * 0.2, PI * 1.65, 16, Color(0.25, 0.55, 0.95, 0.95), 2.0, true)
	draw_line(rc + Vector2(5.0, -2.0), rc + Vector2(9.0, 2.0), Color(0.25, 0.55, 0.95, 0.95), 2.0, true)


func _on_trash_pressed() -> void:
	var st: JournalSticker = target
	if st == null or not is_instance_valid(st) or page == null:
		return
	page.on_sticker_chrome_deleted()
	if is_instance_valid(st):
		st.queue_free()


func _on_rotate_gui(event: InputEvent) -> void:
	if target == null or not is_instance_valid(target) or page == null:
		return
	if _resize_corner >= 0:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_rotating = true
			_rotate_pivot_global = target.get_global_rect().get_center()
			_start_pointer_angle = (mb.global_position - _rotate_pivot_global).angle()
			_start_rot = target.rotation
			get_viewport().set_input_as_handled()
		else:
			if _rotating:
				_rotating = false
				page.clamp_sticker(target)
				page.content_changed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		var ang: float = (mm.global_position - _rotate_pivot_global).angle()
		target.rotation = _start_rot + (ang - _start_pointer_angle)
		page.clamp_sticker(target)
		get_viewport().set_input_as_handled()


func _on_handle_gui(corner_idx: int, event: InputEvent) -> void:
	if target == null or not is_instance_valid(target) or page == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_rotating = false
			_resize_corner = corner_idx
			_start_mouse_global = mb.global_position
			_start_scale = target.get_sticker_scale()
			var ctr_g := target.get_global_rect().get_center()
			_start_dist = maxf(8.0, _start_mouse_global.distance_to(ctr_g))
			get_viewport().set_input_as_handled()
		elif not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _resize_corner == corner_idx:
			_resize_corner = -1
			if page != null:
				page.clamp_sticker(target)
				page.content_changed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _resize_corner == corner_idx:
		var mm := event as InputEventMouseMotion
		var ctr_g := target.get_global_rect().get_center()
		var d1: float = maxf(8.0, mm.global_position.distance_to(ctr_g))
		var ratio: float = d1 / _start_dist
		target.set_sticker_scale(clampf(_start_scale * ratio, JournalSticker.MIN_SCALE, JournalSticker.MAX_SCALE))
		if page != null:
			page.clamp_sticker(target)
		get_viewport().set_input_as_handled()
