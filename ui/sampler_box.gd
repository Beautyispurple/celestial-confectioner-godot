extends CanvasLayer
## Slide-down Marzi's Sampler Box; Tab or handle toggles. Does not pause the scene tree.

const BOX_SCENE := preload("res://ui/box_breathing_overlay.tscn")
const SIFT_SCENE := preload("res://ui/sensory_sifting_panel.tscn")
const COLD_SHEEN_SCENE := preload("res://ui/cold_sheen_panel.tscn")
const CANDY_SLOT_SCENE := preload("res://ui/sampler_candy_skill_slot.tscn")

const _PANEL_OPEN_H := 720.0
const _GRID_COLS := 5
const _GRID_ROWS := 10
const _GRID_SLOTS := _GRID_COLS * _GRID_ROWS

const _SKILLS_TAB := "TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills"

@onready var _handle_strip: Control = $TopBar/RootRow/HandleStrip
@onready var _handle_panel: PanelContainer = $TopBar/RootRow/HandleStrip/HandleRow/HandlePanel
@onready var _handle: Button = $TopBar/RootRow/HandleStrip/HandleRow/HandlePanel/Handle

var _sb_panel_base: StyleBoxFlat
var _sb_panel_hover: StyleBoxFlat
var _sb_panel_pressed: StyleBoxFlat
@onready var _panel: PanelContainer = $TopBar/RootRow/SlidePanel
@onready var _mode_tabs: TabContainer = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs
@onready var _grid: GridContainer = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/Scroll/Grid
@onready var _minigame_host: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost
@onready var _breathing_slot: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/BreathingSlot
@onready var _sifting_slot: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/SiftingSlot
@onready var _cold_sheen_slot: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/ColdSheenSlot
@onready var _back_button: Button = $TopBar/RootRow/SlidePanel/Margin/VBox/ModeTabs/Skills/MinigameHost/MInner/BackButton

var _open: bool = false
var _breathing: Control = null
var _sifting: Control = null
var _cold_sheen: Control = null
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
	for c in _grid.get_children():
		c.queue_free()
	_slot_buttons.clear()
	for i in _GRID_SLOTS:
		var b: SamplerCandySkillSlot = CANDY_SLOT_SCENE.instantiate() as SamplerCandySkillSlot
		b.custom_minimum_size = Vector2(100, 74)
		b.disabled = true
		b.set_slot_text("· · ·")
		b.pressed.connect(_on_skill_slot_pressed.bind(i))
		_grid.add_child(b)
		_slot_buttons.append(b)
	_set_slot_label(0, "Breath\nTempering")
	_set_slot_label(1, "Breath\nAeration")
	_set_slot_label(2, "Sensory\nSifting")
	_set_slot_label(3, "Cold\nSheen")
	_set_slot_label(4, "Dragee\ntoolkit")


func _set_slot_label(idx: int, t: String) -> void:
	if idx >= 0 and idx < _slot_buttons.size():
		var slot: SamplerCandySkillSlot = _slot_buttons[idx] as SamplerCandySkillSlot
		if slot:
			slot.set_slot_text(t)


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


func _on_mode_tab_selected(_tab: int) -> void:
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
		or v == "panic_points"
	):
		_apply_all_slot_visibility()


func _apply_all_slot_visibility() -> void:
	var temper_u: bool = int(float(str(Dialogic.VAR.get_variable("breath_tempering_unlocked", 0)))) != 0
	var aer_u: bool = int(float(str(Dialogic.VAR.get_variable("breath_aeration_unlocked", 0)))) != 0
	var sift_u: bool = int(float(str(Dialogic.VAR.get_variable("sensory_sifting_unlocked", 0)))) != 0
	var cold_u: bool = int(float(str(Dialogic.VAR.get_variable("cold_sheen_unlocked", 0)))) != 0
	var drag_u: bool = CelestialDrageeDisposal.is_dragee_sampler_unlocked()
	if _slot_buttons.size() > 0:
		_slot_buttons[0].visible = temper_u
		_slot_buttons[0].disabled = not temper_u
		_refresh_slot_wrapper(0, false, temper_u and not _slot_buttons[0].disabled)
	if _slot_buttons.size() > 1:
		_slot_buttons[1].visible = aer_u
		var can_aerate: bool = aer_u and CelestialVNState.get_panic_points() >= 2
		_slot_buttons[1].disabled = not can_aerate
		_refresh_slot_wrapper(1, false, aer_u and can_aerate)
	if _slot_buttons.size() > 2:
		_slot_buttons[2].visible = sift_u
		_slot_buttons[2].disabled = not sift_u
		_refresh_slot_wrapper(2, false, sift_u and not _slot_buttons[2].disabled)
	if _slot_buttons.size() > 3:
		_slot_buttons[3].visible = cold_u
		_slot_buttons[3].disabled = not cold_u
		_refresh_slot_wrapper(3, false, cold_u and not _slot_buttons[3].disabled)
	if _slot_buttons.size() > 4:
		_slot_buttons[4].visible = drag_u
		_slot_buttons[4].disabled = not drag_u
		_refresh_slot_wrapper(4, false, drag_u and not _slot_buttons[4].disabled)
	for i in range(5, _slot_buttons.size()):
		_slot_buttons[i].visible = true
		_slot_buttons[i].disabled = true
		_refresh_slot_wrapper(i, true, false)


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
		0:
			_start_temper()
		1:
			_start_aeration()
		2:
			_start_sifting()
		3:
			_start_cold_sheen()
		4:
			_start_dragee_fresh()


func _start_dragee_fresh() -> void:
	await CelestialDrageeDisposal.run_fresh_from_sampler()
	_on_mode_tab_selected(_mode_tabs.current_tab)


func _start_temper() -> void:
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


func _set_back_minigame_emphasis(on: bool) -> void:
	if on:
		_back_button.add_theme_font_size_override("font_size", 22)
	else:
		_back_button.remove_theme_font_size_override("font_size")


func _end_minigame_if_current(kind: String) -> void:
	if _active_minigame != kind:
		return
	_active_minigame = ""
	_set_back_minigame_emphasis(false)
	_back_button.visible = true
	_minigame_host.visible = false
	_breathing_slot.visible = false
	_sifting_slot.visible = false
	_cold_sheen_slot.visible = false
	_scroll_grid_visible(true)
	await _collapse_panel_after_minigame()


func _on_back_pressed() -> void:
	if _active_minigame == "sifting" and _sifting != null:
		_sifting.quit_reset()
	if _active_minigame == "cold_sheen" and _cold_sheen != null:
		_cold_sheen.quit_reset()
	if _breathing != null and _breathing.has_method("stop_exercise"):
		_breathing.stop_exercise()
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
