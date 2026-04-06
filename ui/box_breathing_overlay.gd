extends CanvasLayer
## Box breathing: exactly 4s inhale, 4s hold, 4s exhale, 4s hold per cycle; N cycles then done.

const PHASE_SEC := 4.0
const CYCLES := 3
const R_MIN := 72.0
const R_MAX := 208.0

signal exercise_finished

@onready var _backdrop: ColorRect = $Backdrop
@onready var _glass_panel: PanelContainer = $CenterRoot/Margin/VBox/GlassPanel
@onready var _phase_label: Label = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/PhaseLabel
@onready var _orb: BreathingSugarOrb = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/OrbHost
@onready var _skip_button: Button = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/SkipButton

var _running: bool = false
var _finished_emitted: bool = false
## Seconds elapsed in the current phase (reset each phase; advances when >= PHASE_SEC).
var _phase_elapsed: float = 0.0
var _phase_index: int = 0
var _cycle_index: int = 0
var _tween: Tween
var _hover_tween: Tween


func _ready() -> void:
	layer = 16
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_glass_style()
	_skip_button.pressed.connect(_on_skip_pressed)


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
	_phase_label.add_theme_font_size_override("font_size", 34)
	_backdrop.color = Color(0.08, 0.04, 0.14, 0.52)
	_skip_button.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 0.85))
	_skip_button.add_theme_font_size_override("font_size", 16)


## Await from Dialogic: `do BoxBreathingMinigame.run_post_guide_breathing_cycles()`
func run_three_cycles() -> void:
	_finished_emitted = false
	_cycle_index = 0
	_phase_index = 0
	_phase_elapsed = 0.0
	_running = true
	visible = true
	_skip_button.visible = true
	_reset_orb_for_inhale()
	_enter_phase(0)
	await exercise_finished


func _on_skip_pressed() -> void:
	if _running:
		_finish_exercise()


func _finish_exercise() -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	_running = false
	_kill_tweens()
	_skip_button.visible = false
	visible = false
	_phase_elapsed = 0.0
	exercise_finished.emit()


func _reset_orb_for_inhale() -> void:
	_orb.sphere_radius = R_MIN
	_orb.crystal_strength = 0.0
	_orb.shell_alpha = 0.0
	_orb.molten_warmth = 1.0
	_orb.hover_offset = Vector2.ZERO
	_orb.queue_redraw()


func _kill_tweens() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = null


func _process(delta: float) -> void:
	if not _running:
		return
	_phase_elapsed += delta
	while _phase_elapsed >= PHASE_SEC and _running:
		_phase_elapsed -= PHASE_SEC
		_advance_after_phase()
	_orb.queue_redraw()


func _advance_after_phase() -> void:
	_phase_index += 1
	if _phase_index > 3:
		_phase_index = 0
		_cycle_index += 1
		if _cycle_index >= CYCLES:
			_finish_exercise()
			return
		_reset_orb_for_inhale()
	_enter_phase(_phase_index)


func _enter_phase(phase: int) -> void:
	_kill_tweens()
	match phase:
		0:
			_phase_label.text = "Inhale"
			_orb.molten_warmth = 1.0
			_orb.crystal_strength = 0.0
			_orb.shell_alpha = 0.0
			_orb.hover_offset = Vector2.ZERO
			_orb.sphere_radius = R_MIN
			_tween = create_tween()
			_tween.set_ease(Tween.EASE_IN_OUT)
			_tween.set_trans(Tween.TRANS_SINE)
			_tween.set_parallel(true)
			_tween.tween_property(_orb, "sphere_radius", R_MAX, PHASE_SEC)
			_tween.tween_property(_orb, "molten_warmth", 1.22, PHASE_SEC * 0.65)
		1:
			_phase_label.text = "Hold"
			_orb.sphere_radius = R_MAX
			_orb.hover_offset = Vector2.ZERO
			_tween = create_tween()
			_tween.set_ease(Tween.EASE_OUT)
			_tween.set_trans(Tween.TRANS_CUBIC)
			_tween.tween_property(_orb, "crystal_strength", 0.9, 1.25)
			_tween.parallel().tween_property(_orb, "molten_warmth", 0.52, 1.4)
		2:
			_phase_label.text = "Exhale"
			_orb.hover_offset = Vector2.ZERO
			_tween = create_tween()
			_tween.set_ease(Tween.EASE_IN_OUT)
			_tween.set_trans(Tween.TRANS_SINE)
			_tween.set_parallel(true)
			_tween.tween_property(_orb, "sphere_radius", R_MIN, PHASE_SEC)
			_tween.tween_property(_orb, "shell_alpha", 0.88, PHASE_SEC * 0.9)
			_tween.tween_property(_orb, "crystal_strength", 0.12, PHASE_SEC)
			_tween.tween_property(_orb, "molten_warmth", 0.32, PHASE_SEC)
		3:
			_phase_label.text = "Hold"
			_orb.sphere_radius = R_MIN
			_hover_tween = create_tween()
			_hover_tween.set_loops()
			_hover_tween.set_ease(Tween.EASE_IN_OUT)
			_hover_tween.set_trans(Tween.TRANS_SINE)
			_hover_tween.tween_property(_orb, "hover_offset", Vector2(0, -5), 1.6)
			_hover_tween.tween_property(_orb, "hover_offset", Vector2(0, 5), 1.6)
