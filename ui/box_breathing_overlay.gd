extends Control
## Hold-based box breathing: 4s LMB inhale, 4s Space hold, 4s RMB exhale, 4s Space hold = one 16s cycle.

@export var embedded: bool = false

const PHASE_SEC := 4.0
const R_MIN := 72.0
const R_MAX := 208.0

signal exercise_finished

enum Phase { INHALE_LMB, HOLD_SPACE_1, EXHALE_RMB, HOLD_SPACE_2 }

@onready var _backdrop: ColorRect = $Backdrop
@onready var _glass_panel: PanelContainer = $CenterRoot/Margin/VBox/GlassPanel
@onready var _phase_label: Label = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/PhaseLabel
@onready var _orb: BreathingSugarOrb = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/OrbHost
@onready var _skip_button: Button = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/SkipButton
@onready var _tempered: Label = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/TemperedLabel

var _running: bool = false
var _finished_emitted: bool = false
var _phase_index: int = 0
var _cycle_index: int = 0
var _cycles_target: int = 3
var _phase_acc: float = 0.0
var _from_sampler: bool = false
var _hover_tween: Tween


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backdrop.visible = not embedded
	_apply_glass_style()
	_skip_button.pressed.connect(_on_skip_pressed)
	_tempered.visible = false
	_tempered.modulate.a = 0.0


func _apply_glass_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.96, 0.99, 0.12)
	sb.border_color = Color(1, 0.85, 0.95, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 20
	_glass_panel.add_theme_stylebox_override("panel", sb)
	_phase_label.add_theme_color_override("font_color", Color(0.98, 0.94, 1.0, 0.95))
	_phase_label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.35, 0.85))
	_phase_label.add_theme_constant_override("outline_size", 6)
	_phase_label.add_theme_font_size_override("font_size", 28)
	_backdrop.color = Color(0.08, 0.04, 0.14, 0.52)
	_skip_button.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 0.85))
	_skip_button.add_theme_font_size_override("font_size", 16)
	_tempered.add_theme_font_size_override("font_size", 42)
	_tempered.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))


## Dialogic intro: three full 16s hold cycles, no stat reward.
func run_three_cycles() -> void:
	await _run_session(3, false)


## Sampler / tempering: one 16s cycle, panic -1 and crisis flag clear.
func run_temper_sampler() -> void:
	await _run_session(1, true)


func _run_session(cycles: int, from_sampler: bool) -> void:
	_finished_emitted = false
	_cycles_target = cycles
	_cycle_index = 0
	_phase_index = 0
	_phase_acc = 0.0
	_from_sampler = from_sampler
	_running = true
	visible = true
	_skip_button.visible = not from_sampler
	_reset_orb_for_inhale()
	_update_phase_prompt()
	await exercise_finished


func _on_skip_pressed() -> void:
	if _running:
		_finish_exercise()


func stop_exercise() -> void:
	_finish_exercise()


func _finish_exercise() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	_running = false
	_kill_hover_tween()
	_skip_button.visible = false
	visible = false
	_phase_acc = 0.0
	_tempered.visible = false
	exercise_finished.emit()


func _reset_orb_for_inhale() -> void:
	_orb.sphere_radius = R_MIN
	_orb.crystal_strength = 0.0
	_orb.shell_alpha = 0.0
	_orb.molten_warmth = 1.0
	_orb.hover_offset = Vector2.ZERO
	_orb.queue_redraw()


func _kill_hover_tween() -> void:
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = null


func _process(delta: float) -> void:
	if not _running:
		return
	if _phase_acc >= PHASE_SEC:
		_advance_phase()
		return
	var ok := _correct_input_for_phase()
	if ok:
		_phase_acc += delta
	_apply_orb_visual()
	_orb.queue_redraw()


func _correct_input_for_phase() -> bool:
	match _phase_index:
		Phase.INHALE_LMB:
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		Phase.HOLD_SPACE_1, Phase.HOLD_SPACE_2:
			return Input.is_physical_key_pressed(KEY_SPACE)
		Phase.EXHALE_RMB:
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	return false


func _apply_orb_visual() -> void:
	var t: float = clampf(_phase_acc / PHASE_SEC, 0.0, 1.0)
	match _phase_index:
		Phase.INHALE_LMB:
			_orb.sphere_radius = lerpf(R_MIN, R_MAX, t)
			_orb.molten_warmth = lerpf(1.0, 1.22, t * 0.65)
		Phase.HOLD_SPACE_1:
			_orb.sphere_radius = R_MAX
			_orb.crystal_strength = lerpf(0.0, 0.9, t)
			_orb.molten_warmth = lerpf(1.0, 0.52, t)
		Phase.EXHALE_RMB:
			_orb.sphere_radius = lerpf(R_MAX, R_MIN, t)
			_orb.shell_alpha = lerpf(0.0, 0.88, t * 0.9)
			_orb.crystal_strength = lerpf(0.9, 0.12, t)
			_orb.molten_warmth = lerpf(0.52, 0.32, t)
		Phase.HOLD_SPACE_2:
			_orb.sphere_radius = R_MIN
			if _hover_tween == null or not is_instance_valid(_hover_tween):
				_hover_tween = create_tween()
				_hover_tween.set_loops()
				_hover_tween.set_ease(Tween.EASE_IN_OUT)
				_hover_tween.set_trans(Tween.TRANS_SINE)
				_hover_tween.tween_property(_orb, "hover_offset", Vector2(0, -5), 1.6)
				_hover_tween.tween_property(_orb, "hover_offset", Vector2(0, 5), 1.6)


func _advance_phase() -> void:
	_phase_acc = 0.0
	_kill_hover_tween()
	_phase_index += 1
	if _phase_index > Phase.HOLD_SPACE_2:
		_cycle_index += 1
		if _from_sampler:
			_play_tempered_and_finish()
			return
		if _cycle_index >= _cycles_target:
			_finish_exercise()
			return
		_phase_index = Phase.INHALE_LMB
		_reset_orb_for_inhale()
	_update_phase_prompt()


func _play_tempered_and_finish() -> void:
	_running = false
	var pp: int = CelestialVNState.get_panic_points()
	var new_p: int = clampi(pp - 3, 0, CelestialVNState.PANIC_MAX)
	Dialogic.VAR.set_variable("panic_points", new_p)
	CelestialVNState.notify_sampler_coping_completed()
	_tempered.visible = true
	_tempered.text = "Tempered!"
	_tempered.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tempered, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.2)
	tw.tween_property(_tempered, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_finish_exercise)


func _update_phase_prompt() -> void:
	match _phase_index:
		Phase.INHALE_LMB:
			_phase_label.text = "Press and hold Left Mouse to draw in the sweetness..."
		Phase.HOLD_SPACE_1:
			_phase_label.text = "Press space to hold your breath..."
		Phase.EXHALE_RMB:
			_phase_label.text = "Press and hold Right Mouse to release the heat..."
		Phase.HOLD_SPACE_2:
			_phase_label.text = "Press space to wait for the next breath..."
