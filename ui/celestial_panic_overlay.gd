extends CanvasLayer
## Edge pulse (orange warning / red crisis) + light glitch tint. Sampler sits on a higher layer.

@onready var _edge_top: ColorRect = $Top
@onready var _edge_bottom: ColorRect = $Bottom
@onready var _edge_left: ColorRect = $Left
@onready var _edge_right: ColorRect = $Right
@onready var _glitch: ColorRect = $GlitchTint

var _pulse_tween: Tween
var _glitch_tween: Tween


func _ready() -> void:
	layer = 54
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	# Orange / red edge pulse is visual only; never steal clicks from the sampler (layer 65) or VN UI.
	for c in [_edge_top, _edge_bottom, _edge_left, _edge_right, _glitch]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_edges_alpha(0.0)
	_glitch.modulate.a = 0.0
	CelestialVNState.panic_tier_changed.connect(_on_tier_changed)
	CelestialVNState.breath_aeration_edge_suppress_changed.connect(_on_aeration_suppress_changed)
	_apply_panic_visual()


func _on_tier_changed(_tier: int) -> void:
	_apply_panic_visual()


func _on_aeration_suppress_changed(_suppressed: bool) -> void:
	_apply_panic_visual()


func _apply_panic_visual() -> void:
	if _pulse_tween != null and is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
		_pulse_tween = null
	if _glitch_tween != null and is_instance_valid(_glitch_tween):
		_glitch_tween.kill()
		_glitch_tween = null

	if GameSaveManager.is_reduce_motion_enabled():
		_set_edges_alpha(0.0)
		_glitch.modulate.a = 0.0
		return

	if CelestialVNState.is_breath_aeration_edge_suppressed():
		_set_edges_alpha(0.0)
		_glitch.modulate.a = 0.0
		return

	var t: int = CelestialVNState.get_panic_tier()
	if t == CelestialVNState.PanicTier.NORMAL:
		_set_edges_alpha(0.0)
		_glitch.modulate.a = 0.0
		return
	var warn: bool = t == CelestialVNState.PanicTier.WARNING or t == CelestialVNState.PanicTier.LOCK_RATIONAL
	var crisis: bool = t == CelestialVNState.PanicTier.CRISIS
	var col := Color(1.0, 0.45, 0.12, 1.0) if warn else Color(0.95, 0.15, 0.12, 1.0)
	for e in [_edge_top, _edge_bottom, _edge_left, _edge_right]:
		(e as ColorRect).color = col
	var dur_slow := 2.8
	var dur_fast := 1.65 # crisis edge pulse (2× prior 0.825s)
	var dur := dur_fast if crisis else dur_slow
	var hi := 0.55 if crisis else 0.38
	var lo := 0.12
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_method(_set_edges_alpha, lo, hi, dur * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_edges_alpha, hi, lo, dur * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	if crisis:
		_glitch.modulate.a = 0.18
		_glitch_tween = create_tween()
		_glitch_tween.set_loops()
		_glitch_tween.tween_property(_glitch, "modulate:a", 0.32, 0.9)
		_glitch_tween.tween_property(_glitch, "modulate:a", 0.14, 0.9)
	else:
		_glitch.modulate.a = 0.0


func _set_edges_alpha(a: float) -> void:
	for e in [_edge_top, _edge_bottom, _edge_left, _edge_right]:
		var c: Color = (e as ColorRect).color
		c.a = a
		(e as ColorRect).color = c
