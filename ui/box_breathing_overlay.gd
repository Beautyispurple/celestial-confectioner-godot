extends Control
## Hold-based box breathing: 4s LMB inhale, 4s Space hold, 4s RMB exhale, 4s Space hold = one 16s cycle.
## Aeration mode: four 4s phases, inhale / exhale / inhale / exhale (no holds).

@export var embedded: bool = false

const PHASE_SEC := 4.0
const R_MIN := 72.0
const R_MAX := 208.0

const _WORDS_PATH := "res://data/breath_temper_words.json"

## Metronome pitch_scale per beat (0-3) within each 4s phase. 2.0 ~ one octave up.
const _PITCH_INHALE := [0.52, 0.72, 1.0, 1.38]
const _PITCH_HOLD1 := [1.38, 1.38, 1.38, 1.38]
const _PITCH_EXHALE := [1.38, 1.0, 0.72, 0.52]
const _PITCH_HOLD2 := [0.52, 0.52, 0.52, 0.52]

signal exercise_finished

enum Phase { INHALE_LMB, HOLD_SPACE_1, EXHALE_RMB, HOLD_SPACE_2 }

@onready var _backdrop: ColorRect = $Backdrop
@onready var _glass_panel: PanelContainer = $CenterRoot/Margin/VBox/GlassPanel
@onready var _phase_label: Label = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/PhaseLabel
@onready var _word_hint_label: Label = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/WordHintLabel
@onready var _orb: BreathingSugarOrb = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/OrbHost
@onready var _countdown: Label = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/OrbHost/CountdownLabel
@onready var _skip_button: Button = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/SkipButton
@onready var _tempered: Label = $CenterRoot/Margin/VBox/GlassPanel/Margin/VBox/TemperedLabel

var _running: bool = false
var _finished_emitted: bool = false
var _phase_index: int = 0
var _cycle_index: int = 0
var _cycles_target: int = 3
var _phase_acc: float = 0.0
var _from_sampler: bool = false
var _aeration: bool = false
## Sampler Breath Tempering: loop 16s cycles until Back / stop_exercise.
var _temper_sampler_loop_until_stop: bool = false
var _hover_tween: Tween
var _temper_tween: Tween

var _tick_player: AudioStreamPlayer
var _last_tick_countdown: int = -1

var _breath_session_start_unix: float = 0.0

var _pools_loaded: bool = false
var _pool_inhale: PackedStringArray = PackedStringArray()
var _pool_hold1: PackedStringArray = PackedStringArray()
var _pool_exhale: PackedStringArray = PackedStringArray()
var _pool_hold2: PackedStringArray = PackedStringArray()
var _last_word_by_phase: Array[String] = ["", "", "", ""]


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backdrop.visible = not embedded
	_apply_glass_style()
	_skip_button.pressed.connect(_on_skip_pressed)
	_tempered.visible = false
	_tempered.modulate.a = 0.0
	if _countdown:
		_countdown.add_theme_font_size_override("font_size", 56)
		_countdown.add_theme_color_override("font_color", Color(1, 0.97, 1, 0.95))
		_countdown.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.2, 1.0))
		_countdown.add_theme_constant_override("outline_size", 10)
	_setup_tick_player()
	_load_word_pools()


func _apply_glass_style() -> void:
	var sb := StyleBoxFlat.new()
	if embedded:
		sb.bg_color = Color(0.2, 0.16, 0.24, 1.0)
		sb.border_color = Color(1, 0.85, 0.95, 0.72)
	else:
		sb.bg_color = Color(1, 0.96, 0.99, 0.12)
		sb.border_color = Color(1, 0.85, 0.95, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 20
	_glass_panel.add_theme_stylebox_override("panel", sb)
	_base_label_colors()
	_phase_label.add_theme_constant_override("outline_size", 6)
	_phase_label.add_theme_font_size_override("font_size", 28)
	if _word_hint_label:
		_word_hint_label.add_theme_constant_override("outline_size", 5)
		_word_hint_label.add_theme_font_size_override("font_size", 22)
	_backdrop.color = Color(0.08, 0.04, 0.14, 0.52)
	_skip_button.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 0.85))
	_skip_button.add_theme_font_size_override("font_size", 16)
	_tempered.add_theme_font_size_override("font_size", 42)
	_tempered.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))


func _setup_tick_player() -> void:
	_tick_player = AudioStreamPlayer.new()
	_tick_player.name = "BreathTickPlayer"
	var stream: AudioStream = load("res://audio/ui/breath_tick.wav") as AudioStream
	if stream != null:
		_tick_player.stream = stream
	_tick_player.volume_db = -24.0
	add_child(_tick_player)


func _load_word_pools() -> void:
	if _pools_loaded:
		return
	_pools_loaded = true
	var f := FileAccess.open(_WORDS_PATH, FileAccess.READ)
	if f == null:
		_fill_fallback_pools()
		return
	var txt := f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		_pool_inhale = _dict_string_array(d, "inhale_calm")
		_pool_hold1 = _dict_string_array(d, "hold_still")
		_pool_exhale = _dict_string_array(d, "exhale_release")
		_pool_hold2 = _dict_string_array(d, "hold_accomplish")
	else:
		_fill_fallback_pools()
		return
	if _pool_inhale.is_empty() or _pool_hold1.is_empty() or _pool_exhale.is_empty() or _pool_hold2.is_empty():
		_fill_fallback_pools()


func _dict_string_array(d: Dictionary, key: String) -> PackedStringArray:
	if not d.has(key):
		return PackedStringArray()
	var raw: Variant = d[key]
	if raw is Array:
		var out := PackedStringArray()
		for x in raw:
			if x is String:
				var s: String = (x as String).strip_edges()
				if not s.is_empty():
					out.append(s)
		return out
	return PackedStringArray()


func _fill_fallback_pools() -> void:
	_pool_inhale = PackedStringArray([
		"soft", "gather", "fill", "widen", "open", "ease", "gentle", "drift", "slow", "deepen",
		"calm", "still", "quiet", "hush", "breathe", "sip", "swell", "rise", "lift", "bloom",
	])
	_pool_hold1 = PackedStringArray([
		"pause", "settle", "hush", "steady", "rest", "quiet", "hold", "linger", "suspend", "anchor",
	])
	_pool_exhale = PackedStringArray([
		"release", "soften", "unclench", "melt", "drop", "ease", "flow", "unwind", "let", "drain",
	])
	_pool_hold2 = PackedStringArray([
		"held", "complete", "sure", "balanced", "clear", "grounded", "steady", "enough", "here", "done",
	])


func _pool_for_phase(phase: int) -> PackedStringArray:
	match phase:
		Phase.INHALE_LMB:
			return _pool_inhale
		Phase.HOLD_SPACE_1:
			return _pool_hold1
		Phase.EXHALE_RMB:
			return _pool_exhale
		Phase.HOLD_SPACE_2:
			return _pool_hold2
	return PackedStringArray()


func _pick_word_for_phase(phase: int) -> String:
	var pool := _pool_for_phase(phase)
	if pool.is_empty():
		return "breathe"
	var idx: int = randi() % pool.size()
	if pool.size() > 1:
		var last: String = _last_word_by_phase[phase]
		var tries := 0
		while pool[idx] == last and tries < 12:
			idx = randi() % pool.size()
			tries += 1
	_last_word_by_phase[phase] = pool[idx]
	return pool[idx]


func _peak_color_for_phase(phase: int) -> Color:
	match phase:
		Phase.INHALE_LMB:
			return Color(0.72, 0.88, 1.0, 1.0)
		Phase.HOLD_SPACE_1:
			return Color(0.88, 0.78, 1.0, 1.0)
		Phase.EXHALE_RMB:
			return Color(1.0, 0.82, 0.9, 1.0)
		Phase.HOLD_SPACE_2:
			return Color(1.0, 0.92, 0.72, 1.0)
	return Color(1, 1, 1, 1)


func _base_label_colors() -> void:
	if embedded:
		_phase_label.add_theme_color_override("font_color", Color(0.98, 0.94, 1.0, 1.0))
		_phase_label.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.22, 1.0))
	else:
		_phase_label.add_theme_color_override("font_color", Color(0.98, 0.94, 1.0, 0.95))
		_phase_label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.35, 0.85))
	_phase_label.modulate = Color(1, 1, 1, 1)
	if _word_hint_label:
		if embedded:
			_word_hint_label.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 1.0))
			_word_hint_label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.2, 1.0))
		else:
			_word_hint_label.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 0.92))
			_word_hint_label.add_theme_color_override("font_outline_color", Color(0.22, 0.1, 0.32, 0.88))


func _apply_phase_label_visual() -> void:
	if _aeration or _word_hint_label == null:
		return
	var t: float = clampf(_phase_acc / PHASE_SEC, 0.0, 1.0)
	var eased: float = t * t * (3.0 - 2.0 * t)
	var a: float = lerpf(0.15, 1.0, eased)
	var peak: Color = _peak_color_for_phase(_phase_index)
	var base_font: Color
	var base_outline: Color
	if embedded:
		base_font = Color(0.92, 0.88, 1.0, 1.0)
		base_outline = Color(0.12, 0.06, 0.2, 1.0)
	else:
		base_font = Color(0.92, 0.88, 1.0, 0.92)
		base_outline = Color(0.22, 0.1, 0.32, 0.88)
	_word_hint_label.modulate = Color(1.0, 1.0, 1.0, a)
	_word_hint_label.add_theme_color_override("font_color", base_font.lerp(peak, eased))
	_word_hint_label.add_theme_color_override("font_outline_color", base_outline.lerp(peak.darkened(0.35), eased * 0.65))


func _pitch_array_for_phase(phase: int) -> Array:
	match phase:
		Phase.INHALE_LMB:
			return _PITCH_INHALE
		Phase.HOLD_SPACE_1:
			return _PITCH_HOLD1
		Phase.EXHALE_RMB:
			return _PITCH_EXHALE
		Phase.HOLD_SPACE_2:
			return _PITCH_HOLD2
	return _PITCH_INHALE


func _maybe_play_metronome_tick() -> void:
	if _tick_player == null or _tick_player.stream == null:
		return
	if not _running or _aeration:
		return
	var rem: float = PHASE_SEC - _phase_acc
	var n: int = clampi(ceili(rem), 1, int(ceili(PHASE_SEC)))
	if n == _last_tick_countdown:
		return
	_last_tick_countdown = n
	var beat_idx: int = clampi(4 - n, 0, 3)
	var arr: Array = _pitch_array_for_phase(_phase_index)
	var ps: float = float(arr[beat_idx])
	_tick_player.pitch_scale = ps
	_tick_player.play()


## Dialogic intro: three full 16s hold cycles, no stat reward.
func run_three_cycles() -> void:
	await _run_session(3, false, false)


## Sampler / tempering: repeat 16s cycles until Back; each success -3 Heat and coping notify.
func run_temper_sampler() -> void:
	await _run_session(1, true, false)


## Sampler: 16s inhale/exhale only; costs 2 panic, +1 social on success.
func run_aeration_sampler() -> void:
	await _run_session(1, true, true)


func _run_session(cycles: int, from_sampler: bool, aeration: bool) -> void:
	_finished_emitted = false
	_cycles_target = cycles
	_cycle_index = 0
	_phase_index = 0
	_phase_acc = 0.0
	_from_sampler = from_sampler
	_aeration = aeration
	_temper_sampler_loop_until_stop = from_sampler and not aeration
	_running = true
	_breath_session_start_unix = Time.get_unix_time_from_system()
	var mode_str := "aeration" if aeration else ("temper_loop" if from_sampler and not aeration else "fixed_cycles")
	ResearchTelemetry.record_event("breathing_session_start", {"mode": mode_str})
	visible = true
	_skip_button.visible = true
	_skip_button.text = "Back" if from_sampler else "Skip"
	_last_tick_countdown = -1
	_reset_orb_for_inhale()
	_update_phase_prompt()
	_base_label_colors()
	_apply_phase_label_visual()
	_update_countdown()
	await exercise_finished


func _on_skip_pressed() -> void:
	_finish_exercise(false)


func stop_exercise() -> void:
	_finish_exercise(false)


func _finish_exercise(completed_normally: bool = false) -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	var dur := Time.get_unix_time_from_system() - _breath_session_start_unix
	ResearchTelemetry.record_event("breathing_session_end", {
		"duration_sec": dur,
		"completed": completed_normally,
		"skipped": not completed_normally,
		"cycles": float(_cycle_index),
	})
	_running = false
	_aeration = false
	_temper_sampler_loop_until_stop = false
	_kill_hover_tween()
	_kill_temper_tween()
	_skip_button.visible = false
	_skip_button.text = "Skip"
	visible = false
	_phase_acc = 0.0
	_tempered.visible = false
	if _countdown:
		_countdown.text = ""
	_base_label_colors()
	if _word_hint_label:
		_word_hint_label.modulate = Color(1, 1, 1, 1)
		_word_hint_label.text = ""
	exercise_finished.emit()


func _kill_temper_tween() -> void:
	if _temper_tween != null and is_instance_valid(_temper_tween):
		_temper_tween.kill()
	_temper_tween = null


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


func _update_countdown() -> void:
	if _countdown == null:
		return
	if not _running:
		_countdown.text = ""
		return
	var rem: float = PHASE_SEC - _phase_acc
	var n: int = clampi(ceili(rem), 1, int(ceili(PHASE_SEC)))
	_countdown.text = str(n)


func _process(delta: float) -> void:
	if not _running:
		return
	if _phase_acc >= PHASE_SEC:
		_advance_phase()
		_update_countdown()
		return
	var ok := _correct_input_for_phase()
	if ok:
		_phase_acc += delta
	_apply_orb_visual()
	_orb.queue_redraw()
	_update_countdown()
	if not _aeration:
		_maybe_play_metronome_tick()
		_apply_phase_label_visual()


func _aeration_is_inhale() -> bool:
	return _phase_index % 2 == 0


func _correct_input_for_phase() -> bool:
	if _aeration:
		if _aeration_is_inhale():
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
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
	if _aeration:
		if _aeration_is_inhale():
			_orb.sphere_radius = lerpf(R_MIN, R_MAX, t)
			_orb.molten_warmth = lerpf(1.0, 1.22, t * 0.65)
			_orb.crystal_strength = lerpf(0.0, 0.35, t)
			_orb.shell_alpha = lerpf(0.0, 0.25, t * 0.5)
		else:
			_orb.sphere_radius = lerpf(R_MAX, R_MIN, t)
			_orb.shell_alpha = lerpf(0.25, 0.88, t * 0.9)
			_orb.crystal_strength = lerpf(0.35, 0.1, t)
			_orb.molten_warmth = lerpf(1.0, 0.35, t)
		return
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
	_last_tick_countdown = -1
	_kill_hover_tween()
	if _aeration:
		_phase_index += 1
		if _phase_index > 3:
			_play_aeration_finish()
			return
		if _phase_index == 2:
			_reset_orb_for_inhale()
		_update_phase_prompt()
		return

	_phase_index += 1
	if _phase_index > Phase.HOLD_SPACE_2:
		_cycle_index += 1
		if _from_sampler and _temper_sampler_loop_until_stop:
			_complete_temper_sampler_cycle()
			return
		if _cycle_index >= _cycles_target:
			_finish_exercise(true)
			return
		_phase_index = Phase.INHALE_LMB
		_reset_orb_for_inhale()
	_update_phase_prompt()


func _complete_temper_sampler_cycle() -> void:
	_running = false
	if _word_hint_label:
		_word_hint_label.text = ""
	CelestialVNState.apply_direct_panic_delta(-3)
	CelestialVNState.notify_sampler_coping_completed()
	for n in get_tree().get_nodes_in_group("celestial_heat_meter"):
		if n.has_method("start_heat_twinkle"):
			n.start_heat_twinkle()
	_tempered.visible = true
	_tempered.text = "Tempered!"
	_tempered.modulate.a = 0.0
	_kill_temper_tween()
	_temper_tween = create_tween()
	_temper_tween.tween_property(_tempered, "modulate:a", 1.0, 0.35)
	_temper_tween.tween_interval(1.2)
	_temper_tween.tween_property(_tempered, "modulate:a", 0.0, 0.5)
	_temper_tween.tween_callback(_continue_temper_sampler_session)


func _continue_temper_sampler_session() -> void:
	_temper_tween = null
	if _finished_emitted:
		return
	_phase_index = Phase.INHALE_LMB
	_phase_acc = 0.0
	_last_tick_countdown = -1
	_reset_orb_for_inhale()
	_running = true
	_update_phase_prompt()
	_base_label_colors()
	_apply_phase_label_visual()
	_update_countdown()


func _play_aeration_finish() -> void:
	_running = false
	CelestialVNState.apply_direct_panic_delta(-2)
	var soc: int = CelestialVNState.get_social_battery()
	Dialogic.VAR.set_variable(
		"social_battery",
		mini(soc + 1, CelestialVNState.SOCIAL_MAX)
	)
	_tempered.visible = true
	_tempered.text = "Aerated!"
	_tempered.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tempered, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.0)
	tw.tween_property(_tempered, "modulate:a", 0.0, 0.45)
	tw.tween_callback(_finish_exercise.bind(true))


func _update_phase_prompt() -> void:
	if _aeration:
		if _word_hint_label:
			_word_hint_label.text = ""
		if _aeration_is_inhale():
			_phase_label.text = "Press and hold Left Mouse - breathe in for four counts..."
		else:
			_phase_label.text = "Press and hold Right Mouse - breathe out for four counts..."
		return
	match _phase_index:
		Phase.INHALE_LMB:
			_phase_label.text = "Press and hold Left Mouse to draw in the sweetness..."
		Phase.HOLD_SPACE_1:
			_phase_label.text = "Press space to hold your breath..."
		Phase.EXHALE_RMB:
			_phase_label.text = "Press and hold Right Mouse to release the heat..."
		Phase.HOLD_SPACE_2:
			_phase_label.text = "Press space to wait for the next breath..."
	if _word_hint_label:
		_word_hint_label.text = _pick_word_for_phase(_phase_index)
