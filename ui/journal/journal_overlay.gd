extends CanvasLayer
## Fullscreen journal: pencil strip (~25% viewport) + book (~75%). Blocks all input under layer 101.

signal session_ended

var _book_opened: bool = false
var _suspend_category_signal: bool = false

const PAGE_SCENE := preload("res://ui/journal/journal_page_surface.tscn")

## Exact category names (prompt file keys).
const CATEGORIES: Array[String] = [
	"Balance Bars",
	"Thought Taffy",
	"Courage Crunch",
	"Core Candy Hearts",
	"Candy Kisses",
	"Calm Chews",
	"Resilience Rocks",
	"Bubblegum Boundaries",
]

const COLORS: Array[Color] = [
	Color(0.92, 0.2, 0.22, 1.0),
	Color(0.98, 0.55, 0.15, 1.0),
	Color(0.98, 0.9, 0.25, 1.0),
	Color(0.25, 0.72, 0.35, 1.0),
	Color(0.2, 0.45, 0.95, 1.0),
	Color(0.35, 0.22, 0.75, 1.0),
	Color(0.65, 0.35, 0.95, 1.0),
	Color(0.08, 0.08, 0.1, 1.0),
	Color(0.98, 0.98, 1.0, 1.0),
	Color(0.45, 0.28, 0.14, 1.0),
]

var _root: Control
var _pencil_strip: Control
var _book_area: Control
var _closed: Control
var _spread: Control
var _category: OptionButton
var _prompt_label: Label
var _ts_label: Label
var _left_page: JournalPageSurface
var _right_page: JournalPageSurface
var _finish_btn: Button
var _back_btn: Button
var _debounce: Timer

## Pencil case: one rectangle; side/bottom drawers extend from its edges.
var _pencil_case_root: Control
var _case_face: PanelContainer
var _left_drawer_panel: Control
var _right_drawer_panel: Control
var _bottom_sticker_panel: Control
var _rainbow_pencil: JournalRainbowPencilButton

var _prox_left: float = 0.0
var _prox_right: float = 0.0
var _prox_bottom: float = 0.0

var _carrying_sticker_id: String = ""
var _carry_was_pressed: bool = false
var _carry_preview: PanelContainer
var _sticker_pick_buttons: Array[BaseButton] = []

const DRAWER_W := 96.0
const STICKER_DRAWER_H := 76.0
## Reserved band at bottom of pencil case (drawer lives here; never overlaps prompt below strip).
const STICKER_TRACK_PAD := 8.0
## Narrow slabs along the case edges (avoids “always open” from wide left/right zones).
const PROX_SIDE := 118.0
const PROX_EDGE_IN := 26.0
const PROX_BOTTOM_EXT := 108.0
const PROX_HOLD_PX := 104.0
const PROX_OPEN_SMOOTH := 14.0
const PROX_CLOSE_SMOOTH := 5.5
const PENCIL_COLOR_BTN_SCRIPT := preload("res://ui/journal/journal_pencil_color_button.gd")


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("celestial_journal_ui")
	_build_ui()
	CelestialJournal.draft_changed.connect(_on_journal_draft_changed)
	CelestialJournal.view_changed.connect(_on_journal_view_changed)
	_debounce = Timer.new()
	_debounce.wait_time = 0.35
	_debounce.one_shot = true
	_debounce.timeout.connect(_flush_draft_to_save)
	add_child(_debounce)
	hide()
	call_deferred("_apply_pencil_strip_height")
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.disconnect(_on_viewport_size_changed)


func _on_viewport_size_changed() -> void:
	call_deferred("_apply_pencil_strip_height")
	call_deferred("_apply_pencil_case_layout")


func _apply_pencil_strip_height() -> void:
	if _pencil_strip == null:
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	## 3×4 pencils + tools + margins + internal sticker track (no overflow over book header).
	var face_min: float = 48.0 * 3.0 + 10.0 * 2.0 + 44.0 + 36.0
	var track: float = STICKER_DRAWER_H + STICKER_TRACK_PAD + 6.0
	var h: float = maxf(vh * 0.26, face_min + track + 20.0)
	_pencil_strip.custom_minimum_size = Vector2(0, h)
	call_deferred("_apply_pencil_case_layout")
	call_deferred("_on_pencil_case_root_resized")


func _apply_pencil_case_layout() -> void:
	if _pencil_case_root == null:
		return
	var vw: float = get_viewport().get_visible_rect().size.x
	var w: float = clampf(vw * 0.74, 540.0, 960.0)
	_pencil_case_root.custom_minimum_size.x = w
	var vh2: float = get_viewport().get_visible_rect().size.y
	var face_min2: float = 48.0 * 3.0 + 10.0 * 2.0 + 44.0 + 36.0
	var track2: float = STICKER_DRAWER_H + STICKER_TRACK_PAD + 6.0
	_pencil_case_root.custom_minimum_size.y = maxf(face_min2 + track2 + 16.0, vh2 * 0.24)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.09, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_carry_preview = PanelContainer.new()
	_carry_preview.visible = false
	_carry_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_carry := StyleBoxFlat.new()
	sb_carry.bg_color = Color(1, 1, 1, 0.88)
	sb_carry.set_corner_radius_all(8)
	sb_carry.set_border_width_all(2)
	sb_carry.border_color = Color(0.55, 0.45, 0.7, 1.0)
	_carry_preview.add_theme_stylebox_override("panel", sb_carry)
	var cl := Label.new()
	cl.add_theme_font_size_override("font_size", 28)
	_carry_preview.add_child(cl)
	_carry_preview.set_meta("lbl", cl)
	_root.add_child(_carry_preview)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	_root.add_child(v)
	_pencil_strip = _make_pencil_strip()
	v.add_child(_pencil_strip)
	## Drawers can extend over the book; keep strip above prompt/header when overlapping.
	_pencil_strip.z_index = 24
	_book_area = Control.new()
	_book_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_book_area.z_index = 0
	v.add_child(_book_area)
	_closed = _make_closed_book()
	_spread = _make_spread()
	_book_area.add_child(_closed)
	_book_area.add_child(_spread)
	_spread.visible = false
	_book_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book_area.child_entered_tree.connect(func(_n: Node) -> void: _fit_book())


func _fit_book() -> void:
	pass


func _make_closed_book() -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.85, 0.45, 0.55, 1.0)
	sb.set_corner_radius_all(18)
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.45, 0.15, 0.25, 1.0)
	p.add_theme_stylebox_override("panel", sb)
	var btn := Button.new()
	btn.text = "Open your journal"
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.custom_minimum_size = Vector2(420, 120)
	btn.pressed.connect(_on_open_book_pressed)
	p.add_child(btn)
	c.add_child(p)
	return c


func _on_open_book_pressed() -> void:
	_book_opened = true
	var tw := create_tween()
	tw.tween_property(_closed, "modulate:a", 0.0, 0.22)
	await tw.finished
	_closed.visible = false
	_spread.visible = true
	_spread.modulate.a = 0.0
	var tw2 := create_tween()
	tw2.tween_property(_spread, "modulate:a", 1.0, 0.28)
	await tw2.finished


func _make_spread() -> Control:
	var c := MarginContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_theme_constant_override("margin_left", 12)
	c.add_theme_constant_override("margin_right", 12)
	c.add_theme_constant_override("margin_bottom", 12)
	var v := VBoxContainer.new()
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.add_child(v)
	## Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_category = OptionButton.new()
	for cat in CATEGORIES:
		_category.add_item(cat)
	_category.custom_minimum_size.x = 220
	_category.item_selected.connect(_on_category_selected)
	header.add_child(_category)
	_prompt_label = Label.new()
	_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.add_theme_font_size_override("font_size", 22)
	header.add_child(_prompt_label)
	var reroll := Button.new()
	reroll.text = "New prompt"
	reroll.pressed.connect(_on_reroll)
	header.add_child(reroll)
	_ts_label = Label.new()
	_ts_label.text = ""
	header.add_child(_ts_label)
	_finish_btn = Button.new()
	_finish_btn.text = "Finish"
	_finish_btn.pressed.connect(_on_finish)
	header.add_child(_finish_btn)
	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.add_theme_font_size_override("font_size", 26)
	_back_btn.add_theme_color_override("font_color", Color(1, 0.95, 0.95, 1))
	_back_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.55, 0.1, 0.2, 1.0)
	bsb.set_corner_radius_all(10)
	_back_btn.add_theme_stylebox_override("normal", bsb)
	_back_btn.pressed.connect(_on_back_pressed)
	header.add_child(_back_btn)
	v.add_child(header)
	## Nav row
	var nav := HBoxContainer.new()
	var nav_l := Button.new()
	nav_l.text = "◀ Older"
	nav_l.pressed.connect(_on_nav_older)
	var nav_r := Button.new()
	nav_r.text = "Newer ▶"
	nav_r.pressed.connect(_on_nav_newer)
	nav.add_child(nav_l)
	nav.add_child(nav_r)
	v.add_child(nav)
	## Pages
	var pages := HSplitContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.split_offset = int(get_viewport().get_visible_rect().size.x * 0.5)
	var wrap_l := PanelContainer.new()
	var wrap_r := PanelContainer.new()
	var sbp := StyleBoxFlat.new()
	sbp.bg_color = Color(0.96, 0.93, 0.88, 1.0)
	sbp.set_border_width_all(2)
	sbp.border_color = Color(0.7, 0.55, 0.45, 1.0)
	wrap_l.add_theme_stylebox_override("panel", sbp)
	wrap_r.add_theme_stylebox_override("panel", sbp.duplicate())
	_left_page = PAGE_SCENE.instantiate() as JournalPageSurface
	_right_page = PAGE_SCENE.instantiate() as JournalPageSurface
	_left_page.page_id = "left"
	_right_page.page_id = "right"
	_left_page.content_changed.connect(_on_page_changed)
	_right_page.content_changed.connect(_on_page_changed)
	wrap_l.custom_minimum_size = Vector2(200, 200)
	wrap_r.custom_minimum_size = Vector2(200, 200)
	wrap_l.add_child(_left_page)
	wrap_r.add_child(_right_page)
	pages.add_child(wrap_l)
	pages.add_child(wrap_r)
	v.add_child(pages)
	return c


func _make_pencil_strip() -> Control:
	var outer := MarginContainer.new()
	outer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	outer.custom_minimum_size = Vector2(0, 0)
	var sb_strip := StyleBoxFlat.new()
	sb_strip.bg_color = Color(0.92, 0.88, 0.95, 1.0)
	sb_strip.border_width_bottom = 2
	sb_strip.border_color = Color(0.65, 0.45, 0.7, 1.0)
	var panel_strip := PanelContainer.new()
	panel_strip.add_theme_stylebox_override("panel", sb_strip)
	outer.add_child(panel_strip)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	var sp_l := Control.new()
	sp_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp_r := Control.new()
	sp_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pencil_case_root = Control.new()
	_pencil_case_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pencil_case_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_pencil_case_layout()
	_pencil_case_root.resized.connect(_on_pencil_case_root_resized)
	var sb_left := StyleBoxFlat.new()
	sb_left.bg_color = Color(0.9, 0.86, 0.94, 1.0)
	sb_left.set_corner_radius_all(8)
	sb_left.border_width_left = 3
	sb_left.border_color = Color(0.55, 0.42, 0.65, 1.0)
	_left_drawer_panel = PanelContainer.new()
	_left_drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_left_drawer_panel.add_theme_stylebox_override("panel", sb_left)
	var vl := VBoxContainer.new()
	vl.add_theme_constant_override("separation", 6)
	var lbl_brush := Label.new()
	lbl_brush.text = "Brush"
	lbl_brush.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vl.add_child(lbl_brush)
	for w in [3.0, 5.0, 8.0]:
		var bs := Button.new()
		bs.text = str(int(w))
		var ww: float = float(w)
		bs.pressed.connect(func() -> void: _set_width(ww))
		vl.add_child(bs)
	_left_drawer_panel.add_child(vl)
	_right_drawer_panel = PanelContainer.new()
	_right_drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_right_drawer_panel.add_theme_stylebox_override("panel", sb_left.duplicate())
	var vr := VBoxContainer.new()
	vr.add_theme_constant_override("separation", 6)
	var lbl_er := Label.new()
	lbl_er.text = "Eraser"
	lbl_er.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vr.add_child(lbl_er)
	var b_ers := Button.new()
	b_ers.text = "Eraser"
	b_ers.pressed.connect(func() -> void: _set_tool(JournalPageSurface.ToolMode.ERASER))
	vr.add_child(b_ers)
	_right_drawer_panel.add_child(vr)
	_bottom_sticker_panel = PanelContainer.new()
	_bottom_sticker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_bot := sb_left.duplicate()
	_bottom_sticker_panel.add_theme_stylebox_override("panel", sb_bot)
	var hb_st := HBoxContainer.new()
	hb_st.add_theme_constant_override("separation", 12)
	hb_st.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl_st := Label.new()
	lbl_st.text = "Stickers"
	lbl_st.add_theme_font_size_override("font_size", 14)
	hb_st.add_child(lbl_st)
	hb_st.add_child(_make_sticker_pick_cell("star"))
	hb_st.add_child(_make_sticker_pick_cell("heart"))
	_bottom_sticker_panel.add_child(hb_st)
	## Drawers first (underneath), opaque face on top hides them when closed.
	_pencil_case_root.add_child(_left_drawer_panel)
	_pencil_case_root.add_child(_right_drawer_panel)
	_pencil_case_root.add_child(_bottom_sticker_panel)
	var sb_face := StyleBoxFlat.new()
	sb_face.bg_color = Color(0.94, 0.9, 0.97, 1.0)
	sb_face.set_corner_radius_all(12)
	sb_face.set_border_width_all(2)
	sb_face.border_color = Color(0.62, 0.48, 0.72, 1.0)
	_case_face = PanelContainer.new()
	_case_face.mouse_filter = Control.MOUSE_FILTER_STOP
	_case_face.z_index = 10
	_case_face.add_theme_stylebox_override("panel", sb_face)
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var pencil_grid := GridContainer.new()
	pencil_grid.columns = 4
	pencil_grid.add_theme_constant_override("h_separation", 10)
	pencil_grid.add_theme_constant_override("v_separation", 10)
	for i in COLORS.size():
		var pc := PENCIL_COLOR_BTN_SCRIPT.new()
		pc.setup(i, COLORS[i])
		pc.color_chosen.connect(func(idx: int) -> void: _pick_color(idx))
		pencil_grid.add_child(pc)
	_rainbow_pencil = JournalRainbowPencilButton.new()
	_rainbow_pencil.rainbow_toggled.connect(_on_rainbow_toggled)
	pencil_grid.add_child(_rainbow_pencil)
	v.add_child(pencil_grid)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	var b_pen := Button.new()
	b_pen.text = "Pencil"
	b_pen.pressed.connect(func() -> void: _set_tool(JournalPageSurface.ToolMode.PENCIL))
	var b_txt := Button.new()
	b_txt.text = "Aa"
	b_txt.add_theme_font_size_override("font_size", 22)
	b_txt.tooltip_text = "Text — click on the page to type"
	b_txt.pressed.connect(func() -> void: _set_tool(JournalPageSurface.ToolMode.TEXT))
	tools.add_child(b_pen)
	tools.add_child(b_txt)
	v.add_child(tools)
	pad.add_child(v)
	_case_face.add_child(pad)
	_pencil_case_root.add_child(_case_face)
	row.add_child(sp_l)
	row.add_child(_pencil_case_root)
	row.add_child(sp_r)
	panel_strip.add_child(row)
	call_deferred("_on_pencil_case_root_resized")
	return outer


func _on_pencil_case_root_resized() -> void:
	if _case_face == null or _pencil_case_root == null:
		return
	var rsz: Vector2 = _pencil_case_root.size
	var track_h: float = STICKER_DRAWER_H + STICKER_TRACK_PAD
	var face_h: float = maxf(80.0, rsz.y - track_h)
	_case_face.position = Vector2.ZERO
	_case_face.size = Vector2(rsz.x, face_h)


func _make_sticker_pick_cell(id: String) -> BaseButton:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.custom_minimum_size = Vector2(52, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.55)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.45, 0.38, 0.58, 0.95)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = Color(1, 1, 1, 0.72)
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb.duplicate()
	sb_p.bg_color = Color(0.96, 0.92, 1.0, 0.9)
	btn.add_theme_stylebox_override("pressed", sb_p)
	if id == "heart":
		btn.text = "♥"
		btn.add_theme_color_override("font_color", Color(1, 0.42, 0.55, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.35, 0.5, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.3, 0.45, 1))
	else:
		btn.text = "★"
		btn.add_theme_color_override("font_color", Color(1, 0.82, 0.28, 1))
		btn.add_theme_color_override("font_hover_color", Color(1, 0.75, 0.2, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.65, 0.15, 1))
	btn.add_theme_font_size_override("font_size", 30)
	var sid: String = id
	btn.button_down.connect(func() -> void: _on_sticker_pick_button_down(sid))
	_sticker_pick_buttons.append(btn)
	return btn


func _on_sticker_pick_button_down(sid: String) -> void:
	if CelestialJournal.is_viewing_history_readonly():
		return
	_start_carry_sticker(sid)


func _start_carry_sticker(sid: String) -> void:
	_carrying_sticker_id = sid
	_carry_preview.visible = true
	var lbl: Label = _carry_preview.get_meta("lbl") as Label
	if lbl != null:
		lbl.text = "♥" if sid == "heart" else "★"
		lbl.add_theme_color_override(
			"font_color",
			Color(1, 0.42, 0.55, 1) if sid == "heart" else Color(1, 0.82, 0.28, 1)
		)
	_carry_preview.custom_minimum_size = Vector2(52, 52)
	_carry_preview.size = _carry_preview.custom_minimum_size


func _try_finish_carry_drop(global_pos: Vector2) -> void:
	if _carrying_sticker_id.is_empty():
		return
	var sid: String = _carrying_sticker_id
	_carrying_sticker_id = ""
	_carry_preview.visible = false
	if _left_page.try_drop_palette_sticker(global_pos, sid):
		return
	_right_page.try_drop_palette_sticker(global_pos, sid)


func _pick_color(idx: int) -> void:
	if idx >= 0 and idx < COLORS.size():
		_left_page.stroke_color = COLORS[idx]
		_right_page.stroke_color = COLORS[idx]
		_left_page.rainbow_mode = false
		_right_page.rainbow_mode = false
		if _rainbow_pencil != null:
			_rainbow_pencil.set_rainbow(false)


func _on_rainbow_toggled(on: bool) -> void:
	_left_page.rainbow_mode = on
	_right_page.rainbow_mode = on


func _set_tool(m: int) -> void:
	_left_page.tool_mode = m
	_right_page.tool_mode = m


func _set_width(w: float) -> void:
	_left_page.brush_width = w
	_right_page.brush_width = w


func run_session() -> void:
	show()
	_book_opened = false
	_prox_left = 0.0
	_prox_right = 0.0
	_prox_bottom = 0.0
	CelestialJournal.set_journal_session_active(true)
	_refresh_all()
	await session_ended
	CelestialJournal.set_journal_session_active(false)


func _refresh_all() -> void:
	var d: Dictionary = CelestialJournal.get_current_entry_for_display()
	_prompt_label.text = str(d.get("prompt_text", ""))
	var idx := CATEGORIES.find(str(d.get("category", CATEGORIES[0])))
	_suspend_category_signal = true
	if idx >= 0:
		_category.select(idx)
	_suspend_category_signal = false
	var started: int = int(d.get("started_at_unix", Time.get_unix_time_from_system()))
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(started)
	_ts_label.text = "%04d-%02d-%02d  %02d:%02d" % [int(dt.year), int(dt.month), int(dt.day), int(dt.hour), int(dt.minute)]
	_left_page.deserialize_page(d.get("left", {}) as Dictionary)
	_right_page.deserialize_page(d.get("right", {}) as Dictionary)
	var ro: bool = CelestialJournal.is_viewing_history_readonly()
	_left_page.set_readonly(ro)
	_right_page.set_readonly(ro)
	_finish_btn.disabled = ro
	_category.disabled = ro
	for sb in _sticker_pick_buttons:
		if is_instance_valid(sb):
			sb.disabled = ro
	if ro or _book_opened:
		_closed.visible = false
		_spread.visible = true
		_spread.modulate.a = 1.0
	else:
		_closed.visible = true
		_closed.modulate.a = 1.0
		_spread.visible = false


func _on_category_selected(index: int) -> void:
	if _suspend_category_signal:
		return
	if CelestialJournal.is_viewing_history_readonly():
		return
	var cat: String = _category.get_item_text(index)
	CelestialJournal.apply_category_and_random_prompt(cat)
	_refresh_all()


func _on_reroll() -> void:
	if CelestialJournal.is_viewing_history_readonly():
		return
	CelestialJournal.reroll_prompt()
	_refresh_all()


func _on_nav_older() -> void:
	CelestialJournal.navigate_to_older()


func _on_nav_newer() -> void:
	CelestialJournal.navigate_to_newer()


func _on_journal_draft_changed() -> void:
	_refresh_all()


func _on_journal_view_changed() -> void:
	_refresh_all()


func _on_page_changed() -> void:
	_debounce.start()


func _flush_draft_to_save() -> void:
	if CelestialJournal.is_viewing_history_readonly():
		return
	var d: Dictionary = CelestialJournal.get_draft()
	d["left"] = _left_page.serialize_page()
	d["right"] = _right_page.serialize_page()
	d["category"] = _category.get_item_text(_category.selected)
	d["prompt_text"] = _prompt_label.text
	CelestialJournal.update_draft_from_ui(d)


func _on_finish() -> void:
	_flush_draft_to_save()
	var coins: int = CelestialJournal.finish_current_draft()
	if coins > 0:
		pass
	_refresh_all()


func _on_back_pressed() -> void:
	_flush_draft_to_save()
	CelestialJournal.request_autosave()
	hide()
	session_ended.emit()


func request_close() -> void:
	if not visible:
		return
	_on_back_pressed()


func journal_sticker_selected(_node: Control) -> void:
	pass


func _prox_trigger_left(cr: Rect2) -> Rect2:
	return Rect2(
		cr.position.x - PROX_SIDE,
		cr.position.y - 16.0,
		PROX_SIDE + PROX_EDGE_IN,
		cr.size.y + 32.0
	)


func _prox_trigger_right(cr: Rect2) -> Rect2:
	return Rect2(
		cr.end.x - PROX_EDGE_IN,
		cr.position.y - 16.0,
		PROX_SIDE + PROX_EDGE_IN,
		cr.size.y + 32.0
	)


func _prox_trigger_bottom(cr: Rect2) -> Rect2:
	return Rect2(
		cr.position.x - 20.0,
		cr.end.y - PROX_EDGE_IN,
		cr.size.x + 40.0,
		PROX_BOTTOM_EXT + PROX_EDGE_IN
	)


func _process(delta: float) -> void:
	if not visible:
		return
	if (
		_pencil_case_root == null
		or _left_drawer_panel == null
		or _right_drawer_panel == null
		or _bottom_sticker_panel == null
	):
		return
	var root_sz: Vector2 = _pencil_case_root.size
	if root_sz.y < 8.0 or root_sz.x < 8.0:
		return
	var track_h: float = STICKER_DRAWER_H + STICKER_TRACK_PAD
	var face_h: float = maxf(80.0, root_sz.y - track_h)
	var dh: float = maxf(36.0, face_h - 16.0)
	_left_drawer_panel.size = Vector2(DRAWER_W, dh)
	_right_drawer_panel.size = Vector2(DRAWER_W, dh)
	var rw: float = root_sz.x
	## Tucked under the face when closed (fully inside case); slide outward when open.
	## Nudge X so drawer chrome lines up with the case face borders (face has inner padding / style).
	const LEFT_DRAWER_NUDGE_X := -4.0
	const RIGHT_DRAWER_NUDGE_X := 20.0
	var x_left_closed: float = 0.0 + LEFT_DRAWER_NUDGE_X
	var x_left_open: float = -DRAWER_W + 14.0 + LEFT_DRAWER_NUDGE_X
	_left_drawer_panel.position = Vector2(lerpf(x_left_closed, x_left_open, _prox_left), 8.0)
	var x_right_closed: float = rw - DRAWER_W + RIGHT_DRAWER_NUDGE_X
	var x_right_open: float = rw - DRAWER_W + 22.0 + RIGHT_DRAWER_NUDGE_X
	_right_drawer_panel.position = Vector2(lerpf(x_right_closed, x_right_open, _prox_right), 8.0)
	_bottom_sticker_panel.size = Vector2(maxf(40.0, root_sz.x - 16.0), STICKER_DRAWER_H)
	## Bottom drawer lives in the reserved track below the face; closed = flush under face, open = fully in track.
	var y_closed: float = face_h - STICKER_DRAWER_H
	var y_open: float = face_h
	_bottom_sticker_panel.position = Vector2(8.0, lerpf(y_closed, y_open, _prox_bottom))
	var mp := get_viewport().get_mouse_position()
	var face_rect: Rect2 = _case_face.get_global_rect()
	var dl: Rect2 = _left_drawer_panel.get_global_rect().grow(PROX_HOLD_PX)
	var dr: Rect2 = _right_drawer_panel.get_global_rect().grow(PROX_HOLD_PX)
	var db: Rect2 = _bottom_sticker_panel.get_global_rect().grow(PROX_HOLD_PX)
	var open_l: bool = _prox_trigger_left(face_rect).has_point(mp) or (_prox_left > 0.06 and dl.has_point(mp))
	var open_r: bool = _prox_trigger_right(face_rect).has_point(mp) or (_prox_right > 0.06 and dr.has_point(mp))
	var open_b: bool = _prox_trigger_bottom(face_rect).has_point(mp) or (_prox_bottom > 0.06 and db.has_point(mp))
	var step_open: float = minf(1.0, PROX_OPEN_SMOOTH * delta)
	var step_close: float = minf(1.0, PROX_CLOSE_SMOOTH * delta)
	var tl: float = 1.0 if open_l else 0.0
	var tr: float = 1.0 if open_r else 0.0
	var tb: float = 1.0 if open_b else 0.0
	var kl: float = step_open if tl > _prox_left else step_close
	var kr: float = step_open if tr > _prox_right else step_close
	var kb: float = step_open if tb > _prox_bottom else step_close
	_prox_left = lerpf(_prox_left, tl, kl)
	_prox_right = lerpf(_prox_right, tr, kr)
	_prox_bottom = lerpf(_prox_bottom, tb, kb)
	## Ramp z with proximity so drawers don’t “pop” from 0→22 at a threshold.
	_left_drawer_panel.z_index = int(round(lerpf(0.0, 12.0, _prox_left)))
	_right_drawer_panel.z_index = int(round(lerpf(0.0, 12.0, _prox_right)))
	_bottom_sticker_panel.z_index = int(round(lerpf(0.0, 12.0, _prox_bottom)))
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not _carrying_sticker_id.is_empty():
		if _carry_preview != null:
			_carry_preview.visible = true
			_carry_preview.position = _root.get_global_transform().affine_inverse() * (mp - Vector2(24, 24))
		if _carry_was_pressed and not left_down:
			_try_finish_carry_drop(_root.get_global_mouse_position())
	else:
		if _carry_preview != null:
			_carry_preview.visible = false
	_carry_was_pressed = left_down


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
