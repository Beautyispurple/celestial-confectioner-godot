extends CanvasLayer
## Slide-down Marzi's Sampler Box; Tab or handle toggles. Does not pause the scene tree.
##
## Skills tab = six fixed tiles in stacked rows: breath×2, sifting, cold sheen, dragee, journal.
## Registry index 0..5 = skill id for unlock logic and `_on_skill_slot_pressed`; layout is built in `_build_slot_grid`.

const BOX_SCENE := preload("res://ui/box_breathing_overlay.tscn")
const SIFT_SCENE := preload("res://ui/sensory_sifting_panel.tscn")
const COLD_SHEEN_SCENE := preload("res://ui/cold_sheen_panel.tscn")
const CANDY_SLOT_SCENE := preload("res://ui/sampler_candy_skill_slot.tscn")
const JOURNAL_SCENE := preload("res://ui/journal/journal_overlay.tscn")

const _PANEL_OPEN_H := 720.0

const _SKILLS_TAB := "TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills"
## Block Dialogic advance while these Skills-tab minigames run (matches overlay refcount in CelestialVNState).
const _MINIGAMES_BLOCKING_OVERLAY: Array[String] = ["temper", "aeration", "sifting", "cold_sheen"]

@onready var _handle_strip: Control = $TopBar/RootRow/HandleStrip
@onready var _handle_panel: PanelContainer = $TopBar/RootRow/HandleStrip/HandleRow/HandlePanel
@onready var _handle: Button = $TopBar/RootRow/HandleStrip/HandleRow/HandlePanel/Handle

var _sb_panel_base: StyleBoxFlat
var _sb_panel_hover: StyleBoxFlat
var _sb_panel_pressed: StyleBoxFlat
@onready var _panel: PanelContainer = $TopBar/RootRow/SlidePanel
@onready var _mode_tabs: TabContainer = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs
@onready var _skill_rows: VBoxContainer = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/Scroll/SkillRows
@onready var _minigame_host: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost
@onready var _breathing_slot: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/BreathingSlot
@onready var _sifting_slot: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/SiftingSlot
@onready var _cold_sheen_slot: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/ColdSheenSlot
@onready var _back_button: Button = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/BackButton

var _open: bool = false
var _breathing: Control = null
var _sifting: Control = null
var _cold_sheen: Control = null
var _journal: CanvasLayer = null
var _slot_buttons: Array[Button] = []
var _active_minigame: String = "" # "temper" | "aeration" | "sifting" | "cold_sheen" | ""
var _handle_pulse: Tween
var _panel_height_tween: Tween


func _ready() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("celestial_sampler_ui")
	_handle.add_to_group("celestial_sampler_ui")
	_handle_panel.add_to_group("celestial_sampler_ui")
	_back_button.add_to_group("celestial_sampler_ui")
	_panel.add_to_group("celestial_sampler_ui")
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(0, 0)
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_handle.pressed.connect(toggle_open)
	_back_button.pressed.connect(_on_back_pressed)
	CelestialVNState.panic_tier_changed.connect(_on_tier_changed)
	_on_tier_changed(CelestialVNState.get_panic_tier())
	_apply_handle_visual()
	_apply_slide_panel_opaque()
	_ensure_minigame_opaque_bg()
	_build_slot_grid()
	if not Dialogic.VAR.variable_changed.is_connected(_on_dialogic_var_changed):
		Dialogic.VAR.variable_changed.connect(_on_dialogic_var_changed)
	_apply_all_slot_visibility()
	_mode_tabs.set_tab_title(0, "Skills")
	_mode_tabs.set_tab_title(1, "Life tools")
	if not _mode_tabs.tab_selected.is_connected(_on_mode_tab_selected):
		_mode_tabs.tab_selected.connect(_on_mode_tab_selected)
	_handle.mouse_entered.connect(_on_handle_mouse_entered)
	_handle.mouse_exited.connect(_on_handle_mouse_exited)
	_handle.button_down.connect(_on_handle_button_down)
	_handle.button_up.connect(_on_handle_button_up)
	if not _panel.resized.is_connected(_on_panel_resized):
		_panel.resized.connect(_on_panel_resized)
	call_deferred("_configure_root_sizing")


func _build_slot_grid() -> void:
	for c in _skill_rows.get_children():
		c.queue_free()
	_slot_buttons.clear()
	# Row 1: both breath skills side by side.
	var row_breath := HBoxContainer.new()
	row_breath.alignment = BoxContainer.ALIGNMENT_CENTER
	row_breath.add_theme_constant_override("separation", 10)
	_skill_rows.add_child(row_breath)
	for i in [SamplerSkillsRegistry.SLOT_BREATH_TEMPERING, SamplerSkillsRegistry.SLOT_BREATH_AERATION]:
		var b: SamplerCandySkillSlot = _make_skill_slot_button(i)
		row_breath.add_child(b)
		_slot_buttons.append(b)
	# Rows 2–5: one skill each (sensory sifting, cold sheen, dragee, journal).
	for i in [SamplerSkillsRegistry.SLOT_SENSORY_SIFTING, SamplerSkillsRegistry.SLOT_COLD_SHEEN, SamplerSkillsRegistry.SLOT_DRAGEE_TOOLKIT, SamplerSkillsRegistry.SLOT_JOURNAL]:
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
	b.pressed.connect(_on_skill_slot_pressed.bind(idx))
	return b


func _configure_root_sizing() -> void:
	var tb := $TopBar as Control
	tb.anchor_left = 0.0
	tb.anchor_top = 0.0
	tb.anchor_right = 1.0
	tb.anchor_bottom = 0.0
	tb.offset_left = 0.0
	tb.offset_top = 0.0
	tb.offset_right = 0.0
	tb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_fit_root_to_content()


func _fit_root_to_content() -> void:
	var rr := $TopBar/RootRow as Control
	rr.reset_size()
	var h: float = rr.get_combined_minimum_size().y
	if h < 1.0:
		h = 1.0
	var tb := $TopBar as Control
	tb.anchor_bottom = tb.anchor_top
	tb.offset_bottom = h


func refresh_slot_visibility() -> void:
	_apply_all_slot_visibility()


func _kill_panel_height_tween() -> void:
	if _panel_height_tween != null and is_instance_valid(_panel_height_tween):
		_panel_height_tween.kill()
	_panel_height_tween = null


func _minigame_panel_target_height() -> float:
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var strip_h: float = maxf(_handle_strip.get_combined_minimum_size().y, _handle_strip.size.y)
	strip_h += 6.0
	return maxf(_PANEL_OPEN_H, vp_h - strip_h)


func _expand_panel_for_minigame() -> void:
	_kill_panel_height_tween()
	var target: float = _minigame_panel_target_height()
	if absf(_panel.custom_minimum_size.y - target) < 2.0:
		_fit_root_to_content()
		return
	_panel_height_tween = create_tween()
	_panel_height_tween.tween_property(_panel, "custom_minimum_size:y", target, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await _panel_height_tween.finished
	_panel_height_tween = null
	_fit_root_to_content()


func _collapse_panel_after_minigame() -> void:
	if not _open:
		return
	_kill_panel_height_tween()
	if absf(_panel.custom_minimum_size.y - _PANEL_OPEN_H) < 2.0:
		_fit_root_to_content()
		return
	_panel_height_tween = create_tween()
	_panel_height_tween.tween_property(_panel, "custom_minimum_size:y", _PANEL_OPEN_H, 0.32).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await _panel_height_tween.finished
	_panel_height_tween = null
	_fit_root_to_content()


func _on_panel_resized() -> void:
	_fit_root_to_content()


func reset_for_menu() -> void:
	if _active_minigame in _MINIGAMES_BLOCKING_OVERLAY:
		CelestialVNState.end_blocking_overlay_vn()
	if _active_minigame == "journal" and _journal != null and _journal.has_method("request_close"):
		_journal.request_close()
	_kill_panel_height_tween()
	_open = false
	_back_button.visible = true
	CelestialVNState.set_sampler_blocking_vn(false)
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(0, 0)
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_scroll_grid_visible(true)
	_stop_minigames()
	_active_minigame = ""
	call_deferred("_fit_root_to_content")


func _scroll_grid_visible(v: bool) -> void:
	var sc: ScrollContainer = get_node_or_null("%s/Scroll" % _SKILLS_TAB) as ScrollContainer
	if sc:
		sc.visible = v


func _on_mode_tab_selected(tab: int) -> void:
	var tab_name := "Skills" if tab == 0 else "Life tools"
	ResearchTelemetry.record_event("sampler_tab", {"tab": tab_name})
	var lt: Node = _mode_tabs.get_node_or_null("LifeTools")
	if lt == null:
		return
	for c in lt.get_children():
		if c.has_method("_rebuild"):
			c.call("_rebuild")


func _stop_minigames() -> void:
	if _breathing != null and _breathing.has_method("stop_exercise"):
		_breathing.stop_exercise()
	if _sifting != null and _sifting.has_method("quit_reset"):
		_sifting.quit_reset()
	if _cold_sheen != null and _cold_sheen.has_method("quit_reset"):
		_cold_sheen.quit_reset()


func _apply_handle_visual() -> void:
	var r := 12
	var pad_h := 14
	var pad_v := 8
	_sb_panel_base = _make_handle_stylebox(Color(0.12, 0.1, 0.14, 1.0), Color(1, 0.82, 0.94, 0.55), r, pad_h, pad_v)
	_sb_panel_hover = _make_handle_stylebox(Color(0.18, 0.12, 0.2, 1.0), Color(1, 0.88, 0.98, 0.65), r, pad_h, pad_v)
	_sb_panel_pressed = _make_handle_stylebox(Color(0.08, 0.06, 0.1, 1.0), Color(1, 0.75, 0.9, 0.6), r, pad_h, pad_v)
	_handle_panel.add_theme_stylebox_override("panel", _sb_panel_base)
	var empty := StyleBoxEmpty.new()
	_handle.add_theme_stylebox_override("normal", empty)
	_handle.add_theme_stylebox_override("hover", empty)
	_handle.add_theme_stylebox_override("pressed", empty)
	_handle.add_theme_stylebox_override("focus", empty)
	_handle.add_theme_color_override("font_color", Color(0.95, 0.93, 0.98, 1))
	_handle.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.96, 1))
	_handle.add_theme_color_override("font_pressed_color", Color(0.9, 0.85, 0.92, 1))
	_handle.add_theme_font_size_override("font_size", 17)


func _on_handle_mouse_entered() -> void:
	_handle_panel.add_theme_stylebox_override(
		"panel", _sb_panel_pressed if _handle.button_pressed else _sb_panel_hover
	)


func _on_handle_mouse_exited() -> void:
	if _handle.button_pressed:
		return
	_handle_panel.add_theme_stylebox_override("panel", _sb_panel_base)


func _on_handle_button_down() -> void:
	_handle_panel.add_theme_stylebox_override("panel", _sb_panel_pressed)


func _on_handle_button_up() -> void:
	var next: StyleBoxFlat = _sb_panel_hover if _handle.is_hovered() else _sb_panel_base
	_handle_panel.add_theme_stylebox_override("panel", next)


func _apply_slide_panel_opaque() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.16, 1.0)
	sb.border_color = Color(1, 0.85, 0.95, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	_panel.add_theme_stylebox_override("panel", sb)


func _ensure_minigame_opaque_bg() -> void:
	if _minigame_host.get_node_or_null("OpaqueBg") != null:
		return
	var cr := ColorRect.new()
	cr.name = "OpaqueBg"
	cr.color = Color(0.1, 0.08, 0.14, 1.0)
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minigame_host.add_child(cr)
	_minigame_host.move_child(cr, 0)


func _on_dialogic_var_changed(info: Dictionary) -> void:
	var v: String = str(info.get("variable", ""))
	if v == "dragee_disposal_unlocked":
		CelestialDrageeDisposal.sync_unlock_flag_from_dialogic()
	if (
		v == "breath_tempering_unlocked"
		or v == "breath_aeration_unlocked"
		or v == "sensory_sifting_unlocked"
		or v == "cold_sheen_unlocked"
		or v == "dragee_disposal_unlocked"
		or v == "journal_unlocked"
		or v == "panic_points"
	):
		_apply_all_slot_visibility()


func _apply_all_slot_visibility() -> void:
	# One tile per registry entry only; tiles stay visible so grid positions never shift.
	for i in SamplerSkillsRegistry.skill_slots().size():
		if i >= _slot_buttons.size():
			break
		var def: Dictionary = SamplerSkillsRegistry.skill_slots()[i]
		var unlocked: bool = _sampler_skill_unlocked(def)
		var can_activate: bool = _sampler_skill_can_activate(def, unlocked)
		_apply_fixed_skill_slot(i, unlocked, can_activate)


func _sampler_skill_unlocked(def: Dictionary) -> bool:
	var key: String = str(def.get("dialog", ""))
	if key == "_dragee_sampler_":
		return CelestialDrageeDisposal.is_dragee_sampler_unlocked()
	return int(float(str(Dialogic.VAR.get_variable(key, 0)))) != 0


func _sampler_skill_can_activate(def: Dictionary, unlocked: bool) -> bool:
	if not unlocked:
		return false
	match str(def.get("gate", "always")):
		"panic_ge_2":
			return CelestialVNState.get_panic_points() >= 2
		_:
			return true


func _apply_fixed_skill_slot(idx: int, unlocked: bool, can_activate: bool) -> void:
	if idx < 0 or idx >= _slot_buttons.size():
		return
	var b: Button = _slot_buttons[idx]
	b.visible = true
	b.disabled = not can_activate
	var interactable: bool = unlocked and can_activate
	_refresh_slot_wrapper(idx, not unlocked, interactable)


func _refresh_slot_wrapper(idx: int, placeholder: bool, interactable: bool) -> void:
	if idx < 0 or idx >= _slot_buttons.size():
		return
	var slot: SamplerCandySkillSlot = _slot_buttons[idx] as SamplerCandySkillSlot
	if slot:
		slot.set_visual_state(placeholder, interactable)


func _make_handle_stylebox(bg: Color, border: Color, corner_r: int, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(corner_r)
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


func _unhandled_input(event: InputEvent) -> void:
	if CelestialVNState.is_blocking_overlay_vn():
		return
	if event.is_action_pressed("celestial_sampler_toggle"):
		toggle_open()
		get_viewport().set_input_as_handled()


## Saves that earned the Huck beat before dragee unlock was fixed: unlock migrates on load; show skill popup once on first Sampler open.
func _maybe_show_dragee_migration_tutorial() -> void:
	if not _open:
		return
	if _minigame_host.visible:
		return
	if not CelestialDrageeDisposal.is_dragee_sampler_unlocked():
		return
	if int(float(str(Dialogic.VAR.get_variable("dragee_disposal_tutorial_done", 0)))) != 0:
		return
	if int(float(str(Dialogic.VAR.get_variable("dragee_huck_story_bonus_done", 0)))) == 0:
		return
	var tut: Node = get_node_or_null("/root/CelestialTutorial")
	if tut != null and tut.has_method("prologue_tutorial_dragee_disposal_unlocked"):
		await tut.prologue_tutorial_dragee_disposal_unlocked()
	Dialogic.VAR.set_variable("dragee_disposal_tutorial_done", 1)


func _maybe_run_sampler_intro_chain() -> void:
	if not _open:
		return
	if _minigame_host.visible:
		return
	var tut: Node = get_node_or_null("/root/CelestialTutorial")
	if tut != null and tut.has_method("run_sampler_first_open_chain"):
		await tut.run_sampler_first_open_chain()


func _on_tier_changed(tier: int) -> void:
	var crisis: bool = tier == CelestialVNState.PanicTier.CRISIS
	if crisis:
		if _handle_pulse == null or not is_instance_valid(_handle_pulse):
			_handle_pulse = create_tween()
			_handle_pulse.set_loops()
			_handle_pulse.tween_property(_handle, "modulate", Color(1.25, 1.05, 1.1, 1.0), 0.28)
			_handle_pulse.tween_property(_handle, "modulate", Color.WHITE, 0.28)
	else:
		if _handle_pulse != null and is_instance_valid(_handle_pulse):
			_handle_pulse.kill()
			_handle_pulse = null
		_handle.modulate = Color.WHITE


func toggle_open() -> void:
	_open = not _open
	if _open:
		ResearchTelemetry.record_event("sampler_open", {"open": true})
		_apply_all_slot_visibility()
		_kill_panel_height_tween()
		_panel.visible = true
		CelestialVNState.set_sampler_blocking_vn(true)
		var tw := create_tween()
		tw.tween_property(_panel, "custom_minimum_size:y", _PANEL_OPEN_H, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		await tw.finished
		await _maybe_show_dragee_migration_tutorial()
		await _maybe_run_sampler_intro_chain()
	else:
		ResearchTelemetry.record_event("sampler_close", {"open": false})
		if _active_minigame == "journal" and _journal != null and _journal.has_method("request_close"):
			_journal.request_close()
		if _minigame_host.visible:
			await _on_back_pressed()
		_kill_panel_height_tween()
		var tw2 := create_tween()
		tw2.tween_property(_panel, "custom_minimum_size:y", 0.0, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		await tw2.finished
		_panel.visible = false
		CelestialVNState.set_sampler_blocking_vn(false)
		_fit_root_to_content()


func _on_skill_slot_pressed(idx: int) -> void:
	match idx:
		SamplerSkillsRegistry.SLOT_BREATH_TEMPERING:
			_start_temper()
		SamplerSkillsRegistry.SLOT_BREATH_AERATION:
			_start_aeration()
		SamplerSkillsRegistry.SLOT_SENSORY_SIFTING:
			_start_sifting()
		SamplerSkillsRegistry.SLOT_COLD_SHEEN:
			_start_cold_sheen()
		SamplerSkillsRegistry.SLOT_DRAGEE_TOOLKIT:
			_start_dragee_fresh()
		SamplerSkillsRegistry.SLOT_JOURNAL:
			_start_journal()


func _start_dragee_fresh() -> void:
	ResearchTelemetry.record_event("minigame_start", {"tool": "dragee_toolkit"})
	await CelestialDrageeDisposal.run_fresh_from_sampler()
	_on_mode_tab_selected(_mode_tabs.current_tab)


func _start_temper() -> void:
	ResearchTelemetry.record_event("minigame_start", {"tool": "breath_tempering"})
	CelestialVNState.begin_blocking_overlay_vn()
	await _expand_panel_for_minigame()
	_set_back_minigame_emphasis(true)
	_scroll_grid_visible(false)
	_minigame_host.visible = true
	_breathing_slot.visible = true
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_active_minigame = "temper"
	if _breathing == null:
		_breathing = BOX_SCENE.instantiate() as Control
		_breathing.embedded = true
		_breathing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_breathing_slot.add_child(_breathing)
	_back_button.visible = false
	await _breathing.run_temper_sampler()
	await _end_minigame_if_current("temper")


func _start_aeration() -> void:
	if CelestialVNState.get_panic_points() < 2:
		return
	ResearchTelemetry.record_event("minigame_start", {"tool": "breath_aeration"})
	CelestialVNState.begin_blocking_overlay_vn()
	await _expand_panel_for_minigame()
	_set_back_minigame_emphasis(true)
	_scroll_grid_visible(false)
	_minigame_host.visible = true
	_breathing_slot.visible = true
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_active_minigame = "aeration"
	if _breathing == null:
		_breathing = BOX_SCENE.instantiate() as Control
		_breathing.embedded = true
		_breathing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_breathing_slot.add_child(_breathing)
	_back_button.visible = false
	await _breathing.run_aeration_sampler()
	await _end_minigame_if_current("aeration")


func _start_sifting() -> void:
	ResearchTelemetry.record_event("minigame_start", {"tool": "sensory_sifting"})
	CelestialVNState.begin_blocking_overlay_vn()
	await _expand_panel_for_minigame()
	_set_back_minigame_emphasis(true)
	_scroll_grid_visible(false)
	_minigame_host.visible = true
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
	ResearchTelemetry.record_event("minigame_start", {"tool": "cold_sheen"})
	CelestialVNState.begin_blocking_overlay_vn()
	await _expand_panel_for_minigame()
	_set_back_minigame_emphasis(true)
	_scroll_grid_visible(false)
	_minigame_host.visible = true
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


func _start_journal() -> void:
	if int(float(str(Dialogic.VAR.get_variable("journal_unlocked", 0)))) == 0:
		return
	ResearchTelemetry.record_event("minigame_start", {"tool": "journal"})
	await _expand_panel_for_minigame()
	_set_back_minigame_emphasis(true)
	_scroll_grid_visible(false)
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_active_minigame = "journal"
	_back_button.visible = true
	CelestialVNState.begin_blocking_overlay_vn()
	if _journal == null:
		_journal = JOURNAL_SCENE.instantiate() as CanvasLayer
		get_tree().root.add_child(_journal)
	await _journal.run_session()
	CelestialVNState.end_blocking_overlay_vn()
	await _end_minigame_if_current("journal")


func _set_back_minigame_emphasis(on: bool) -> void:
	if on:
		_back_button.add_theme_font_size_override("font_size", 22)
	else:
		_back_button.remove_theme_font_size_override("font_size")


func _end_minigame_if_current(kind: String) -> void:
	if _active_minigame != kind:
		return
	ResearchTelemetry.record_event("minigame_complete", {"tool": _telemetry_tool_id(kind)})
	if kind in _MINIGAMES_BLOCKING_OVERLAY:
		CelestialVNState.end_blocking_overlay_vn()
	_active_minigame = ""
	_set_back_minigame_emphasis(false)
	_back_button.visible = true
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_scroll_grid_visible(true)
	await _collapse_panel_after_minigame()


func _telemetry_tool_id(kind: String) -> String:
	match kind:
		"temper":
			return "breath_tempering"
		"aeration":
			return "breath_aeration"
		"sifting":
			return "sensory_sifting"
		"cold_sheen":
			return "cold_sheen"
		"journal":
			return "journal"
		_:
			return kind


func _on_back_pressed() -> void:
	if not _active_minigame.is_empty():
		ResearchTelemetry.record_event("minigame_abort", {"tool": _telemetry_tool_id(_active_minigame)})
	var ending_kind: String = _active_minigame
	if _active_minigame == "journal" and _journal != null and _journal.has_method("request_close"):
		_journal.request_close()
		return
	if _active_minigame == "sifting" and _sifting != null:
		_sifting.quit_reset()
	if _active_minigame == "cold_sheen" and _cold_sheen != null:
		_cold_sheen.quit_reset()
	if _breathing != null and _breathing.has_method("stop_exercise"):
		_breathing.stop_exercise()
	if ending_kind in _MINIGAMES_BLOCKING_OVERLAY:
		CelestialVNState.end_blocking_overlay_vn()
	_active_minigame = ""
	_set_back_minigame_emphasis(false)
	_back_button.visible = true
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_scroll_grid_visible(true)
	if _open:
		await _collapse_panel_after_minigame()
	else:
		_fit_root_to_content()
