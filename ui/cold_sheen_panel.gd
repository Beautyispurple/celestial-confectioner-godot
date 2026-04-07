extends Control
## Short Cold Sheen interaction: one beat, then Heat change + splash VFX.

signal finished

const _FEEDBACK_OK: Array[String] = ["Sheened!", "Cold finish."]
const _FEEDBACK_CRISIS: Array[String] = [
	"Only a little—still too hot.",
	"A sip of cold—not the whole bucket.",
]

@onready var _instruction: Label = $RootVBox/Instruction
@onready var _splash_button: Button = $RootVBox/SplashButton
@onready var _feedback: Label = $RootVBox/FeedbackLabel

var _running: bool = false
var _water_splash: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_feedback.visible = false
	_splash_button.pressed.connect(_on_splash_pressed)


func run_cold_sheen() -> void:
	_running = true
	visible = true
	_feedback.visible = false
	_instruction.text = "Cup cold water in your hands — one quick splash when you're ready."
	await finished


func quit_reset() -> void:
	if not _running:
		return
	_running = false
	visible = false
	_feedback.visible = false
	_splash_button.disabled = false
	finished.emit()


func _on_splash_pressed() -> void:
	if not _running:
		return
	if _water_splash == null or not is_instance_valid(_water_splash):
		_water_splash = get_tree().get_first_node_in_group("celestial_water_splash")
	_splash_button.disabled = true
	if _water_splash != null and _water_splash.has_method("play_splash"):
		await _water_splash.play_splash()
	var crisis: bool = CelestialVNState.apply_cold_sheen_effect()
	_show_feedback(crisis)
	await get_tree().create_timer(1.2).timeout
	_running = false
	visible = false
	_splash_button.disabled = false
	finished.emit()


func _show_feedback(crisis: bool) -> void:
	var pool: Array[String] = _FEEDBACK_CRISIS if crisis else _FEEDBACK_OK
	var t: String = pool[randi() % pool.size()]
	_feedback.text = t
	_feedback.visible = true
