extends CanvasLayer
## Main menu only: meta-unlocked skills from all save slots; practice mode (no VN/Dialogic stat writes).

const BOX_SCENE := preload("res://ui/box_breathing_overlay.tscn")
const SIFT_SCENE := preload("res://ui/sensory_sifting_panel.tscn")
const COLD_SHEEN_SCENE := preload("res://ui/cold_sheen_panel.tscn")
const CANDY_SLOT_SCENE := preload("res://ui/sampler_candy_skill_slot.tscn")
const JOURNAL_SCENE := preload("res://ui/journal/journal_overlay.tscn")

var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _skill_rows: VBoxContainer
var _minigame_host: Control
var _m_inner: Control
var _breathing_slot: Control
var _sifting_slot: Control
var _cold_sheen_slot: Control
var _back_button: Button
var _close_button: Button

var _slot_buttons: Array[Button] = []
var _meta_unlocks: Array[bool] = []
var _breathing: Control = null
var _sifting: Control = null
var _cold_sheen: Control = null
var _journal: CanvasLayer = null
var _active_minigame: String = ""


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if _active_minigame.is_empty():
			hide_case()
		else:
			_on_back_pressed()
		get_viewport().set_input_as_handled()


func show_case() -> void:
	_refresh_meta_unlocks()
	_apply_grid()
	visible = true


func hide_case() -> void:
	if not _active_minigame.is_empty():
		await _on_back_pressed()
	SkillPracticeContext.menu_practice = false
	visible = false


func _refresh_meta_unlocks() -> void:
	_meta_unlocks = GameSaveManager.compute_meta_skill_unlocks()


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.04, 0.03, 0.08, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(920, 700)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.16, 0.98)
	sb.border_color = Color(1, 0.78, 0.92, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_top = 14
	sb.content_margin_right = 18
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_panel.add_child(outer)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	outer.add_child(title_row)
	var title := Label.new()
	title.text = "Confectioner's Case"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.94, 0.98, 1))
	title_row.add_child(title)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(100, 40)
	_close_button.pressed.connect(hide_case)
	title_row.add_child(_close_button)

	var sub := Label.new()
	sub.text = "Skills you've unlocked in any save. Practice here without changing a playthrough."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.82, 0.78, 0.9, 1))
	outer.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_skill_rows = VBoxContainer.new()
	_skill_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_skill_rows)

	_minigame_host = Control.new()
	_minigame_host.visible = false
	_minigame_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minigame_host.custom_minimum_size = Vector2(0, 380)
	outer.add_child(_minigame_host)

	var opaque := ColorRect.new()
	opaque.name = "OpaqueBg"
	opaque.color = Color(0.08, 0.06, 0.12, 1.0)
	opaque.set_anchors_preset(Control.PRESET_FULL_RECT)
	opaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minigame_host.add_child(opaque)

	_m_inner = Control.new()
	_m_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_m_inner.offset_left = 8
	_m_inner.offset_top = 8
	_m_inner.offset_right = -8
	_m_inner.offset_bottom = -8
	_minigame_host.add_child(_m_inner)

	_breathing_slot = Control.new()
	_breathing_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_breathing_slot.visible = false
	_m_inner.add_child(_breathing_slot)

	_sifting_slot = Control.new()
	_sifting_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sifting_slot.visible = false
	_m_inner.add_child(_sifting_slot)

	_cold_sheen_slot = Control.new()
	_cold_sheen_slot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cold_sheen_slot.visible = false
	_m_inner.add_child(_cold_sheen_slot)

	_back_button = Button.new()
	_back_button.text = "Back to case"
	_back_button.custom_minimum_size = Vector2(200, 44)
	_back_button.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_back_button.offset_top = 8
	_back_button.offset_bottom = 52
	_back_button.visible = false
	_back_button.pressed.connect(_on_back_pressed)
	_m_inner.add_child(_back_button)

	_build_slot_grid()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _active_minigame.is_empty():
			hide_case()


func _build_slot_grid() -> void:
	for c in _skill_rows.get_children():
		c.queue_free()
	_slot_buttons.clear()
	var row_breath := HBoxContainer.new()
	row_breath.alignment = BoxContainer.ALIGNMENT_CENTER
	row_breath.add_theme_constant_override("separation", 10)
	_skill_rows.add_child(row_breath)
	for i in [SamplerSkillsRegistry.SLOT_BREATH_TEMPERING, SamplerSkillsRegistry.SLOT_BREATH_AERATION]:
		var b: SamplerCandySkillSlot = _make_skill_slot_button(i)
		row_breath.add_child(b)
		_slot_buttons.append(b)
	for i in [SamplerSkillsRegistry.SLOT_SENSORY_SIFTING, SamplerSkillsRegistry.SLOT_COLD_SHEEN, SamplerSkillsRegistry.SLOT_DRAGEE_DECISIONS, SamplerSkillsRegistry.SLOT_JOURNAL]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		_skill_rows.add_child(row)
		var b2: SamplerCandySkillSlot = _make_skill_slot_button(i)
		row.add_child(b2)
		_slot_buttons.append(b2)


func _make_skill_slot_button(idx: int) -> SamplerCandySkillSlot:
	var def: Dictionary = SamplerSkillsRegistry.skill_slots()[idx]
	var b: SamplerCandySkillSlot = CANDY_SLOT_SCENE.instantiate() as SamplerCandySkillSlot
	b.custom_minimum_size = Vector2(100, 74)
	b.disabled = true
	b.set_slot_text(str(def.get("label", "?")))
	b.tooltip_text = str(def.get("tooltip", ""))
	b.pressed.connect(_on_skill_slot_pressed.bind(idx))
	return b


func _apply_grid() -> void:
	for i in SamplerSkillsRegistry.skill_slots().size():
		if i >= _slot_buttons.size():
			break
		var unlocked: bool = i < _meta_unlocks.size() and _meta_unlocks[i]
		var b: Button = _slot_buttons[i]
		b.disabled = not unlocked
		var slot: SamplerCandySkillSlot = b as SamplerCandySkillSlot
		if slot:
			slot.set_visual_state(not unlocked, unlocked)


func _on_skill_slot_pressed(idx: int) -> void:
	if idx >= _meta_unlocks.size() or not _meta_unlocks[idx]:
		return
	SkillPracticeContext.menu_practice = true
	match idx:
		SamplerSkillsRegistry.SLOT_BREATH_TEMPERING:
			await _start_temper()
		SamplerSkillsRegistry.SLOT_BREATH_AERATION:
			await _start_aeration()
		SamplerSkillsRegistry.SLOT_SENSORY_SIFTING:
			await _start_sifting()
		SamplerSkillsRegistry.SLOT_COLD_SHEEN:
			await _start_cold_sheen()
		SamplerSkillsRegistry.SLOT_DRAGEE_DECISIONS:
			await _start_dragee_fresh()
		SamplerSkillsRegistry.SLOT_JOURNAL:
			await _start_journal()
	SkillPracticeContext.menu_practice = false


func _show_minigame_host() -> void:
	var scroll := _skill_rows.get_parent() as Control
	if scroll:
		scroll.visible = false
	_minigame_host.visible = true
	_back_button.visible = true


func _hide_minigame_host() -> void:
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	var scroll := _skill_rows.get_parent() as Control
	if scroll:
		scroll.visible = true
	_back_button.visible = false
	_active_minigame = ""


func _start_temper() -> void:
	_show_minigame_host()
	_breathing_slot.visible = true
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_active_minigame = "temper"
	if _breathing == null:
		_breathing = BOX_SCENE.instantiate() as Control
		_breathing.embedded = true
		_breathing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_breathing_slot.add_child(_breathing)
	await _breathing.run_temper_sampler()
	await _end_minigame_if_current("temper")


func _start_aeration() -> void:
	CelestialVNState.begin_breath_aeration_edge_suppress()
	_show_minigame_host()
	_breathing_slot.visible = true
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_active_minigame = "aeration"
	if _breathing == null:
		_breathing = BOX_SCENE.instantiate() as Control
		_breathing.embedded = true
		_breathing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_breathing_slot.add_child(_breathing)
	await _breathing.run_aeration_sampler()
	await _end_minigame_if_current("aeration")


func _start_sifting() -> void:
	_show_minigame_host()
	_breathing_slot.visible = false
	_sifting_slot.visible = true
	_cold_sheen_slot.visible = false
	_active_minigame = "sifting"
	if _sifting == null:
		_sifting = SIFT_SCENE.instantiate() as Control
		_sifting.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sifting_slot.add_child(_sifting)
	await _sifting.run_sifting()
	await _end_minigame_if_current("sifting")


func _start_cold_sheen() -> void:
	_show_minigame_host()
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = true
	_active_minigame = "cold_sheen"
	if _cold_sheen == null:
		_cold_sheen = COLD_SHEEN_SCENE.instantiate() as Control
		_cold_sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cold_sheen_slot.add_child(_cold_sheen)
	await _cold_sheen.run_cold_sheen()
	await _end_minigame_if_current("cold_sheen")


func _start_dragee_fresh() -> void:
	await CelestialDrageeDisposal.run_fresh_from_sampler()


func _start_journal() -> void:
	var jbak: Dictionary = CelestialJournal.get_save_data().duplicate(true)
	var scroll := _skill_rows.get_parent() as Control
	if scroll:
		scroll.visible = false
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_back_button.visible = false
	_active_minigame = "journal"
	if _journal == null:
		_journal = JOURNAL_SCENE.instantiate() as CanvasLayer
		get_tree().root.add_child(_journal)
	await _journal.run_session()
	CelestialJournal.load_save_data(jbak)
	await _end_minigame_if_current("journal")


func _end_minigame_if_current(kind: String) -> void:
	if _active_minigame != kind:
		return
	if kind == "aeration":
		CelestialVNState.end_breath_aeration_edge_suppress()
	_active_minigame = ""
	_stop_minigames()
	_hide_minigame_host()


func _stop_minigames() -> void:
	if _breathing != null and _breathing.has_method("stop_exercise"):
		_breathing.stop_exercise()
	if _sifting != null and _sifting.has_method("quit_reset"):
		_sifting.quit_reset()
	if _cold_sheen != null and _cold_sheen.has_method("quit_reset"):
		_cold_sheen.quit_reset()


func _on_back_pressed() -> void:
	if _active_minigame == "journal" and _journal != null and _journal.has_method("request_close"):
		_journal.request_close()
		return
	var ending_kind: String = _active_minigame
	_stop_minigames()
	if ending_kind == "aeration":
		CelestialVNState.end_breath_aeration_edge_suppress()
	_active_minigame = ""
	_hide_minigame_host()
