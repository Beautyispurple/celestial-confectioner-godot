extends Control
## Cold Sheen: fill meter with splashes; Heat/panic changes only once when the meter completes.

signal finished

const METER_MAX := 100
## Tunable splash increment per click (8–12 range).
const METER_SPLASH_STEP := 10

const _FEEDBACK_OK: Array[String] = ["Sheened!", "Cold finish."]
const _FEEDBACK_CRISIS: Array[String] = [
	"Only a little—still too hot.",
	"A sip of cold—not the whole bucket.",
]

@onready var _instruction: Label = $RootVBox/Instruction
@onready var _meter: ProgressBar = $RootVBox/SinkBlock/MeterRow/Meter
@onready var _splash_button: Button = $RootVBox/SplashButton
@onready var _feedback: Label = $RootVBox/FeedbackLabel
@onready var _local_splash_flash: ColorRect = $RootVBox/SinkBlock/BasinRow/BasinWrap/LocalSplashFlash

var _running: bool = false
var _water_splash: Node = null
var _local_flash_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_feedback.visible = false
	_splash_button.pressed.connect(_on_splash_pressed)


func run_cold_sheen() -> void:
	_running = true
	visible = true
	_feedback.visible = false
	_meter.max_value = float(METER_MAX)
	_meter.value = 0.0
	_splash_button.disabled = false
	_instruction.text = "Splash cool water until the meter fills — then you get the cold finish."
	await finished


func quit_reset() -> void:
	if not _running:
		return
	_kill_local_flash_tween()
	_running = false
	visible = false
	_feedback.visible = false
	_meter.value = 0.0
	_splash_button.disabled = false
	finished.emit()


func _on_splash_pressed() -> void:
	if not _running:
		return
	if _meter.value >= float(METER_MAX):
		return
	_meter.value = minf(float(METER_MAX), _meter.value + float(METER_SPLASH_STEP))
	_play_local_sink_flash()
	if _water_splash == null or not is_instance_valid(_water_splash):
		_water_splash = get_tree().get_first_node_in_group("celestial_water_splash")
	if _meter.value >= float(METER_MAX):
		await _complete_minigame()
		return
	if _water_splash != null and _water_splash.has_method("play_splash"):
		await _water_splash.play_splash(false)


func _complete_minigame() -> void:
	_splash_button.disabled = true
	if _water_splash == null or not is_instance_valid(_water_splash):
		_water_splash = get_tree().get_first_node_in_group("celestial_water_splash")
	if _water_splash != null and _water_splash.has_method("play_splash"):
		await _water_splash.play_splash(true)
	var crisis: bool = false
	if not SkillPracticeContext.menu_practice:
		crisis = CelestialVNState.apply_cold_sheen_effect()
	_show_feedback(crisis)
	await get_tree().create_timer(1.2).timeout
	_kill_local_flash_tween()
	_running = false
	visible = false
	_splash_button.disabled = false
	_meter.value = 0.0
	finished.emit()


func _play_local_sink_flash() -> void:
	_kill_local_flash_tween()
	_local_splash_flash.modulate.a = 0.0
	_local_flash_tween = create_tween()
	_local_flash_tween.set_parallel(false)
	_local_flash_tween.tween_property(_local_splash_flash, "modulate:a", 0.75, 0.05)
	_local_flash_tween.tween_property(_local_splash_flash, "modulate:a", 0.0, 0.22).set_ease(Tween.EASE_OUT)


func _kill_local_flash_tween() -> void:
	if _local_flash_tween != null and is_instance_valid(_local_flash_tween):
		_local_flash_tween.kill()
	_local_flash_tween = null
	if is_instance_valid(_local_splash_flash):
		_local_splash_flash.modulate.a = 0.0


func _show_feedback(crisis: bool) -> void:
	var pool: Array[String] = _FEEDBACK_CRISIS if crisis else _FEEDBACK_OK
	var t: String = pool[randi() % pool.size()]
	_feedback.text = t
	_feedback.visible = true
