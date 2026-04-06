extends CanvasLayer
## Slide-down Marzi's Sampler Box; Tab or handle toggles. Does not pause the scene tree.

const BOX_SCENE := preload("res://ui/box_breathing_overlay.tscn")

const _PANEL_OPEN_H := 560.0

@onready var _handle_panel: PanelContainer = $TopBar/RootRow/HandleStrip/HandleRow/HandlePanel
@onready var _handle: Button = $TopBar/RootRow/HandleStrip/HandleRow/HandlePanel/Handle

var _sb_panel_base: StyleBoxFlat
var _sb_panel_hover: StyleBoxFlat
var _sb_panel_pressed: StyleBoxFlat
@onready var _panel: PanelContainer = $TopBar/RootRow/SlidePanel
@onready var _grid: GridContainer = $TopBar/RootRow/SlidePanel/Margin/VBox/Scroll/Grid
@onready var _minigame_host: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/MinigameHost
@onready var _breathing_slot: Control = $TopBar/RootRow/SlidePanel/Margin/VBox/MinigameHost/MInner/BreathingSlot
@onready var _back_button: Button = $TopBar/RootRow/SlidePanel/Margin/VBox/MinigameHost/MInner/BackButton
@onready var _slot1: Button = $TopBar/RootRow/SlidePanel/Margin/VBox/Scroll/Grid/Slot1

var _open: bool = false
var _breathing: Control = null
var _handle_pulse: Tween


func _ready() -> void:
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("celestial_sampler_ui")
	_handle.add_to_group("celestial_sampler_ui")
	_panel.add_to_group("celestial_sampler_ui")
	_back_button.add_to_group("celestial_sampler_ui")
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(0, 0)
	_minigame_host.visible = false
	_handle.pressed.connect(toggle_open)
	_back_button.pressed.connect(_on_back_pressed)
	_slot1.pressed.connect(_on_slot1_pressed)
	CelestialVNState.panic_tier_changed.connect(_on_tier_changed)
	_on_tier_changed(CelestialVNState.get_panic_tier())
	_apply_handle_visual()
	_handle.mouse_entered.connect(_on_handle_mouse_entered)
	_handle.mouse_exited.connect(_on_handle_mouse_exited)
	_handle.button_down.connect(_on_handle_button_down)
	_handle.button_up.connect(_on_handle_button_up)
	if not _panel.resized.is_connected(_on_panel_resized):
		_panel.resized.connect(_on_panel_resized)
	call_deferred("_configure_root_sizing")


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


func _on_panel_resized() -> void:
	_fit_root_to_content()


func reset_for_menu() -> void:
	_open = false
	CelestialVNState.set_sampler_blocking_vn(false)
	_panel.visible = false
	_panel.custom_minimum_size = Vector2(0, 0)
	_minigame_host.visible = false
	_grid.visible = true
	if _breathing != null and _breathing.has_method("stop_exercise"):
		_breathing.stop_exercise()
	call_deferred("_fit_root_to_content")


func _apply_handle_visual() -> void:
	var r := 12
	var pad_h := 14
	var pad_v := 8
	_sb_panel_base = _make_handle_stylebox(Color(0.12, 0.1, 0.14, 0.96), Color(1, 0.82, 0.94, 0.45), r, pad_h, pad_v)
	_sb_panel_hover = _make_handle_stylebox(Color(0.18, 0.12, 0.2, 0.96), Color(1, 0.88, 0.98, 0.6), r, pad_h, pad_v)
	_sb_panel_pressed = _make_handle_stylebox(Color(0.08, 0.06, 0.1, 0.98), Color(1, 0.75, 0.9, 0.55), r, pad_h, pad_v)
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
	if event.is_action_pressed("celestial_sampler_toggle"):
		toggle_open()
		get_viewport().set_input_as_handled()


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
		_panel.visible = true
		CelestialVNState.set_sampler_blocking_vn(true)
		var tw := create_tween()
		tw.tween_property(_panel, "custom_minimum_size:y", _PANEL_OPEN_H, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	else:
		if _minigame_host.visible and _breathing != null:
			_on_back_pressed()
		var tw2 := create_tween()
		tw2.tween_property(_panel, "custom_minimum_size:y", 0.0, 0.32).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		await tw2.finished
		_panel.visible = false
		CelestialVNState.set_sampler_blocking_vn(false)
		_fit_root_to_content()


func _on_slot1_pressed() -> void:
	_grid.visible = false
	_minigame_host.visible = true
	if _breathing == null:
		_breathing = BOX_SCENE.instantiate() as Control
		_breathing.embedded = true
		_breathing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_breathing_slot.add_child(_breathing)
	await _breathing.run_temper_sampler()
	_minigame_host.visible = false
	_grid.visible = true


func _on_back_pressed() -> void:
	if _breathing != null and _breathing.has_method("stop_exercise"):
		_breathing.stop_exercise()
	_minigame_host.visible = false
	_grid.visible = true
