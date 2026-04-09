class_name JournalPageSurface
extends Control
## One journal page: raster pencil layer (PNG round-trip), labels for text, stickers on top.
## Eraser only clears pencil pixels (alpha), not text or stickers.

signal content_changed

const STICKER_PACKED := preload("res://ui/journal/journal_sticker.tscn")
const JOURNAL_STICKER_CHROME := preload("res://ui/journal/journal_sticker_chrome.gd")
## Palette → page: 2.0 = 100% larger than the 1.0 “base” sticker size.
const DEFAULT_PLACED_STICKER_SCALE := 2.0

enum ToolMode { PENCIL, ERASER, TEXT }

var page_id: String = "left"
## Both journal halves accept input for the same entry.
var page_active: bool = true
var tool_mode: int = ToolMode.PENCIL
var brush_width: float = 4.0
var stroke_color: Color = Color(0.15, 0.12, 0.2, 1.0)
## Rainbow: hue advances by arc length while drawing (see _draw_segment).
var rainbow_mode: bool = false
var _rainbow_accum: float = 0.0

var _drawing: bool = false
var _last_pos: Vector2 = Vector2.ZERO

@onready var _paper: ColorRect = $Paper
@onready var _pencil_tex: TextureRect = $PencilLayer
@onready var _text_layer: Control = $TextLayer
@onready var _sticker_layer: Control = $StickerLayer

var _img: Image
var _img_tex: ImageTexture
var _readonly: bool = false
var _selected_sticker: Control = null
var _pending_sticker_id: String = "star"
var _chrome: JournalStickerChrome
var _inline_edit: LineEdit = null
var _inline_guard: bool = false
var _selected_text_block: JournalTextBlock = null


func _ready() -> void:
	_ensure_image()
	_pencil_tex.mouse_filter = Control.MOUSE_FILTER_STOP
	## Stickers sit above the pencil layer but must not steal clicks on empty paper.
	_sticker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome = JOURNAL_STICKER_CHROME.new() as JournalStickerChrome
	_sticker_layer.add_child(_chrome)
	_pencil_tex.gui_input.connect(_on_pencil_gui_input)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	_ensure_image()


func set_readonly(v: bool) -> void:
	_readonly = v
	mouse_filter = Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_STOP


func set_page_active(_v: bool) -> void:
	page_active = true


func set_pending_sticker_id(id: String) -> void:
	_pending_sticker_id = id


func _ensure_image() -> void:
	var sz := Vector2i(maxi(8, int(size.x)), maxi(8, int(size.y)))
	if _img == null or _img.get_width() != sz.x or _img.get_height() != sz.y:
		_img = Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
		_img.fill(Color(0, 0, 0, 0))
		if _img_tex == null:
			_img_tex = ImageTexture.create_from_image(_img)
		else:
			_img_tex.set_image(_img)
		_pencil_tex.texture = _img_tex
	_pencil_tex.set_anchors_preset(Control.PRESET_FULL_RECT)


func _on_pencil_gui_input(event: InputEvent) -> void:
	if _readonly or not page_active:
		return
	if _inline_edit != null and tool_mode != ToolMode.TEXT:
		if event is InputEventMouseButton:
			var mb0 := event as InputEventMouseButton
			if mb0.pressed and mb0.button_index == MOUSE_BUTTON_LEFT:
				_remove_line_edit_committing(true)
	if tool_mode == ToolMode.TEXT and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clear_sticker_selection()
			clear_text_selection()
			_begin_inline_text(mb.position)
			get_viewport().set_input_as_handled()
			return
	if tool_mode != ToolMode.PENCIL and tool_mode != ToolMode.ERASER:
		return
	if event is InputEventMouseButton:
		var mb3 := event as InputEventMouseButton
		if mb3.button_index == MOUSE_BUTTON_LEFT and mb3.pressed:
			clear_sticker_selection()
			clear_text_selection()
		if mb3.button_index == MOUSE_BUTTON_LEFT:
			_drawing = mb3.pressed
			if _drawing:
				_last_pos = mb3.position
				_rainbow_accum = 0.0
				_paint_dot(mb3.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drawing:
		var mm := event as InputEventMouseMotion
		_paint_line(_last_pos, mm.position)
		_last_pos = mm.position
		get_viewport().set_input_as_handled()


func _paint_dot(pos: Vector2) -> void:
	_paint_line(pos, pos)


func _paint_line(a: Vector2, b: Vector2) -> void:
	if _img == null:
		return
	var dist: float = a.distance_to(b)
	var steps: int = maxi(1, int(dist / 2.0))
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		_draw_brush_circle(p)


func _draw_brush_circle(p: Vector2) -> void:
	var col: Color = stroke_color
	if rainbow_mode:
		## Hue advances with arc length along the stroke (wraps 0–1).
		var step: float = maxf(0.5, brush_width * 0.35)
		_rainbow_accum += step * 0.0022
		col = Color.from_hsv(fmod(_rainbow_accum, 1.0), 0.55, 0.95, 1.0)
	var r: int = int(ceilf(brush_width * 0.5))
	var x0: int = maxi(0, int(p.x) - r)
	var y0: int = maxi(0, int(p.y) - r)
	var x1: int = mini(_img.get_width() - 1, int(p.x) + r)
	var y1: int = mini(_img.get_height() - 1, int(p.y) + r)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(p)
			if d <= float(r) + 0.25:
				if tool_mode == ToolMode.ERASER:
					_img.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					_img.set_pixel(x, y, col)
	if _img_tex != null:
		_img_tex.set_image(_img)
	content_changed.emit()


func _begin_inline_text(local_pos: Vector2) -> void:
	if _inline_edit != null:
		_remove_line_edit_committing(true)
	var max_w: float = minf(420.0, maxf(120.0, size.x - local_pos.x - 8.0))
	var le := LineEdit.new()
	le.position = local_pos
	le.custom_minimum_size = Vector2(max_w, 32)
	le.size = le.custom_minimum_size
	le.placeholder_text = "Type…"
	le.add_theme_font_size_override("font_size", 18)
	le.add_theme_color_override("font_color", Color(0.12, 0.1, 0.18, 1.0))
	_text_layer.add_child(le)
	le.text_submitted.connect(_on_inline_submitted)
	le.focus_exited.connect(_on_inline_focus_exited)
	_inline_edit = le
	le.call_deferred("grab_focus")


func _on_inline_submitted(_t: String) -> void:
	_remove_line_edit_committing(true)


func _on_inline_focus_exited() -> void:
	if _inline_guard or _inline_edit == null:
		return
	call_deferred("_deferred_blur_commit_inline")


func _deferred_blur_commit_inline() -> void:
	if _inline_guard or _inline_edit == null:
		return
	if _inline_edit.has_focus():
		return
	_remove_line_edit_committing(true)


func _remove_line_edit_committing(commit: bool) -> void:
	if _inline_edit == null:
		return
	if _inline_guard:
		return
	_inline_guard = true
	var le: LineEdit = _inline_edit
	_inline_edit = null
	if le.focus_exited.is_connected(_on_inline_focus_exited):
		le.focus_exited.disconnect(_on_inline_focus_exited)
	if le.text_submitted.is_connected(_on_inline_submitted):
		le.text_submitted.disconnect(_on_inline_submitted)
	var txt: String = le.text.strip_edges() if commit else ""
	var pos: Vector2 = le.position
	var mw: float = le.size.x
	le.queue_free()
	_inline_guard = false
	if commit and not txt.is_empty():
		_try_add_journal_text_block(pos, txt, mw)


func _try_add_journal_text_block(local_pos: Vector2, txt: String, max_w: float) -> void:
	var use_w: float = minf(max_w, size.x - local_pos.x - 4.0)
	var tb := JournalTextBlock.new()
	_text_layer.add_child(tb)
	tb.setup(txt, use_w, local_pos)
	var sz: Vector2 = tb.size
	if local_pos.x + sz.x > size.x - 4.0:
		push_warning("Journal: text does not fit on this page")
		tb.queue_free()
		return
	if local_pos.y + sz.y > size.y - 4.0:
		push_warning("Journal: text does not fit on this page")
		tb.queue_free()
		return
	_clamp_text_block(tb)
	tb.pressed_block.connect(_on_text_block_pressed)
	tb.drag_ended_block.connect(_on_text_block_drag_end)
	content_changed.emit()


func add_text_from_dict(dd: Dictionary) -> void:
	var d2: Dictionary = JournalTextBlock.from_save_dict(dd as Dictionary)
	var pos: Array = d2.get("pos", [0, 0]) as Array
	var mw: float = float(d2.get("max_w", 200.0))
	var txt: String = str(d2.get("text", ""))
	if txt.is_empty():
		return
	var tb := JournalTextBlock.new()
	_text_layer.add_child(tb)
	tb.setup(txt, mw, Vector2(float(pos[0]), float(pos[1])))
	tb.pressed_block.connect(_on_text_block_pressed)
	tb.drag_ended_block.connect(_on_text_block_drag_end)
	_clamp_text_block(tb)


func _spawn_sticker_at(local_pos: Vector2) -> void:
	var st: Control = STICKER_PACKED.instantiate() as Control
	if st.has_method("setup"):
		st.call("setup", _pending_sticker_id, DEFAULT_PLACED_STICKER_SCALE, 0.0)
	st.position = local_pos
	st.pressed_sticker.connect(_on_sticker_pressed)
	st.drag_ended.connect(_on_sticker_drag_end)
	_sticker_layer.add_child(st)
	_ensure_chrome_on_top()
	_clamp_sticker(st)
	content_changed.emit()
	_on_sticker_pressed(st)


func try_drop_palette_sticker(global_pos: Vector2, sticker_id: String) -> bool:
	if _readonly:
		return false
	if not get_global_rect().has_point(global_pos):
		return false
	clear_sticker_selection()
	var local_p: Vector2 = get_global_transform().affine_inverse() * global_pos
	_pending_sticker_id = sticker_id
	_spawn_sticker_at(local_p)
	return true


func clear_sticker_selection() -> void:
	_selected_sticker = null
	if _chrome != null:
		_chrome.detach()


func clear_text_selection() -> void:
	for c in _text_layer.get_children():
		if c is JournalTextBlock:
			(c as JournalTextBlock).set_selected(false)
	_selected_text_block = null


func _on_text_block_pressed(b: JournalTextBlock) -> void:
	clear_sticker_selection()
	clear_text_selection()
	_selected_text_block = b
	b.set_selected(true)


func _on_text_block_drag_end(b: JournalTextBlock) -> void:
	_clamp_text_block(b)
	content_changed.emit()


func on_sticker_chrome_deleted() -> void:
	_selected_sticker = null
	if _chrome != null:
		_chrome.detach()
	content_changed.emit()


func _ensure_chrome_on_top() -> void:
	if _chrome != null and _chrome.get_parent() == _sticker_layer:
		_sticker_layer.move_child(_chrome, _sticker_layer.get_child_count() - 1)


func _on_sticker_pressed(node: Control) -> void:
	clear_text_selection()
	clear_sticker_selection()
	_selected_sticker = node
	if _chrome != null and node is JournalSticker:
		_chrome.attach_to(node as JournalSticker, self)
	get_tree().call_group_flags(
		SceneTree.GROUP_CALL_DEFERRED, "celestial_journal_ui", "journal_sticker_selected", node
	)


func _on_sticker_drag_end() -> void:
	if _selected_sticker != null:
		_clamp_sticker(_selected_sticker)
	_ensure_chrome_on_top()
	content_changed.emit()


func clamp_sticker(st: Control) -> void:
	_clamp_sticker(st)


func _clamp_text_block(tb: Control) -> void:
	tb.position.x = clampf(tb.position.x, 0.0, maxf(0.0, size.x - tb.size.x))
	tb.position.y = clampf(tb.position.y, 0.0, maxf(0.0, size.y - tb.size.y))


func _clamp_sticker(st: Control) -> void:
	if st is JournalSticker:
		_clamp_journal_sticker(st as JournalSticker)
		return
	var bw: float = st.size.x * absf(st.scale.x)
	var bh: float = st.size.y * absf(st.scale.y)
	st.position.x = clampf(st.position.x, 0.0, maxf(0.0, size.x - bw))
	st.position.y = clampf(st.position.y, 0.0, maxf(0.0, size.y - bh))


func _clamp_journal_sticker(st: JournalSticker) -> void:
	for _i in 4:
		var xf: Transform2D = st.get_transform()
		var sz: Vector2 = st.size
		var corners: Array[Vector2] = [
			xf * Vector2.ZERO,
			xf * Vector2(sz.x, 0.0),
			xf * sz,
			xf * Vector2(0.0, sz.y),
		]
		var mn_x: float = corners[0].x
		var mn_y: float = corners[0].y
		var mx_x: float = corners[0].x
		var mx_y: float = corners[0].y
		for p in corners:
			mn_x = minf(mn_x, p.x)
			mn_y = minf(mn_y, p.y)
			mx_x = maxf(mx_x, p.x)
			mx_y = maxf(mx_y, p.y)
		var bw: float = mx_x - mn_x
		var bh: float = mx_y - mn_y
		if mn_x < 0.0:
			st.position.x -= mn_x
		elif mx_x > size.x:
			st.position.x -= (mx_x - size.x)
		if mn_y < 0.0:
			st.position.y -= mn_y
		elif mx_y > size.y:
			st.position.y -= (mx_y - size.y)
		if bw > size.x * 0.98:
			var k: float = (size.x * 0.98) / maxf(1.0, bw)
			st.set_sticker_scale(st.get_sticker_scale() * k)
		else:
			break


func delete_selected_sticker() -> void:
	if _selected_sticker != null and is_instance_valid(_selected_sticker):
		_selected_sticker.queue_free()
		on_sticker_chrome_deleted()


func serialize_page() -> Dictionary:
	var buf: PackedByteArray = _img.save_png_to_buffer() if _img != null else PackedByteArray()
	var texts: Array = []
	for c in _text_layer.get_children():
		if c is LineEdit:
			continue
		if c is JournalTextBlock:
			texts.append((c as JournalTextBlock).serialize_dict())
		elif c is Label:
			var lbl := c as Label
			texts.append({"text": lbl.text, "pos": [lbl.position.x, lbl.position.y], "max_w": lbl.size.x})
	var stickers: Array = []
	for c in _sticker_layer.get_children():
		if c is JournalSticker and c.has_method("serialize"):
			stickers.append(c.call("serialize"))
	return {
		"pencil_png_b64": Marshalls.raw_to_base64(buf),
		"text_items": texts,
		"stickers": stickers,
	}


func deserialize_page(d: Dictionary) -> void:
	for c in _text_layer.get_children():
		c.queue_free()
	for c in _sticker_layer.get_children():
		if c is JournalSticker:
			c.queue_free()
	var b64: String = str(d.get("pencil_png_b64", ""))
	if not b64.is_empty():
		var raw: PackedByteArray = Marshalls.base64_to_raw(b64)
		var img2: Image = Image.new()
		var err: Error = img2.load_png_from_buffer(raw)
		if err == OK:
			_img = img2
			if _img_tex == null:
				_img_tex = ImageTexture.create_from_image(_img)
			else:
				_img_tex.set_image(_img)
			_pencil_tex.texture = _img_tex
	else:
		_ensure_image()
		if _img != null:
			_img.fill(Color(0, 0, 0, 0))
			if _img_tex != null:
				_img_tex.set_image(_img)
	var items: Array = d.get("text_items", []) as Array
	for it in items:
		if it is Dictionary:
			add_text_from_dict(it as Dictionary)
	var starr: Array = d.get("stickers", []) as Array
	for st in starr:
		if st is Dictionary:
			var sd: Dictionary = JournalSticker.deserialize(st)
			var node: Control = STICKER_PACKED.instantiate() as Control
			if node.has_method("setup"):
				node.call(
					"setup",
					str(sd.get("id", "star")),
					float(sd.get("scale", 1.0)),
					float(sd.get("rotation", 0.0))
				)
			var pos2: Array = sd.get("pos", [0, 0]) as Array
			node.position = Vector2(float(pos2[0]), float(pos2[1]))
			node.pressed_sticker.connect(_on_sticker_pressed)
			node.drag_ended.connect(_on_sticker_drag_end)
			_sticker_layer.add_child(node)
	call_deferred("_ensure_chrome_on_top")
