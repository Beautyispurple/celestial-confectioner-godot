extends Control
## Full-viewport splash flash; parent under SamplerBox CanvasLayer (not SlidePanel). Click-through.

## Photosensitivity: minimum ms between full-screen flash peaks to reduce strobing / seizure risk from rapid clicks.
const SPLASH_PEAK_MIN_INTERVAL_MS := 450.0
## Photosensitivity: max opacity for spam splashes (most feedback is local on the sink in cold_sheen_panel).
const SPLASH_SPAM_PEAK_ALPHA := 0.2
## Photosensitivity: completion splash is a single stronger cue at 100% meter.
const SPLASH_COMPLETION_PEAK_ALPHA := 0.52
const SPLASH_FADE_DURATION_SPAM := 0.38
const SPLASH_FADE_DURATION_COMPLETION := 0.48

var _last_peak_ms: float = -100000.0
var _active_tween: Tween = null


func _ready() -> void:
	add_to_group("celestial_water_splash")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## is_completion: stronger single cue at 100% meter; spam uses low opacity and strict peak throttle.
func play_splash(is_completion: bool = false) -> void:
	if is_completion:
		await _play_completion_flash()
	else:
		var now_ms: float = float(Time.get_ticks_msec())
		if now_ms - _last_peak_ms < SPLASH_PEAK_MIN_INTERVAL_MS:
			return
		_last_peak_ms = now_ms
		await _run_fullscreen_flash(SPLASH_SPAM_PEAK_ALPHA, SPLASH_FADE_DURATION_SPAM)


func _play_completion_flash() -> void:
	var now_ms: float = float(Time.get_ticks_msec())
	if now_ms - _last_peak_ms < SPLASH_PEAK_MIN_INTERVAL_MS:
		await get_tree().create_timer((SPLASH_PEAK_MIN_INTERVAL_MS - (now_ms - _last_peak_ms)) / 1000.0).timeout
	_last_peak_ms = float(Time.get_ticks_msec())
	await _run_fullscreen_flash(SPLASH_COMPLETION_PEAK_ALPHA, SPLASH_FADE_DURATION_COMPLETION)


func _run_fullscreen_flash(peak_alpha: float, fade_duration: float) -> void:
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.kill()
		_active_tween = null
	visible = true
	modulate = Color(1, 1, 1, 0)
	_active_tween = create_tween()
	_active_tween.set_parallel(false)
	_active_tween.tween_property(self, "modulate:a", peak_alpha, 0.05).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await _active_tween.finished
	_active_tween = null
	visible = false
	modulate = Color.WHITE
