extends Node
## Dialogic `do CelestialTutorial.<method>()` — blocking tutorials for Heat / Sampler / unlock copy.

const LAYER_SCENE := preload("res://ui/celestial_tutorial_layer.tscn")

var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_ensure_layer")


func _ensure_layer() -> void:
	if _layer != null and is_instance_valid(_layer):
		return
	_layer = LAYER_SCENE.instantiate() as CanvasLayer
	get_tree().root.add_child(_layer)


func _await_tutorial_layer_ready() -> void:
	_ensure_layer()
	if _layer != null and not _layer.is_node_ready():
		await _layer.ready


func prologue_tutorial_heat_meter() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_heat_tutorial()


func prologue_tutorial_sampler_box() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_sampler_arrow_tutorial()


func prologue_tutorial_breath_tempering_unlocked() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"You have unlocked Breath Tempering in Marzi's Sampler Box! You can use this skill anytime during gameplay to bring down her heat. It is also available on the main menu to bring down your own heat."
	)


func run_sampler_first_open_chain() -> void:
	if _is_sampler_chain_done():
		return
	if not is_breath_tempering_unlocked():
		return
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"Depending on your choices, Marzi will unlock different skills in her Sampler Box. Use them for different effects."
	)
	await _layer.show_plain_tutorial(
		"Sometimes Marzi has to use a skill more than once to gain the desired effect..."
	)
	Dialogic.VAR.set_variable("sampler_tutorial_chain_done", 1)


func _is_sampler_chain_done() -> bool:
	return int(float(str(Dialogic.VAR.get_variable("sampler_tutorial_chain_done", 0)))) != 0


func is_breath_tempering_unlocked() -> bool:
	return int(float(str(Dialogic.VAR.get_variable("breath_tempering_unlocked", 0)))) != 0


func prologue_tutorial_breath_aeration_unlocked() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"You have unlocked Breath Aeration in Marzi's Sampler Box! Follow the inhale and exhale rhythm — no breath-holds — to trade a little Heat for Social Battery."
	)


func prologue_tutorial_sensory_sifting_unlocked() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"You have unlocked Sensory Sifting (Name 5 Things) in Marzi's Sampler Box! Use it during gameplay to ground Marzi through sight, touch, sound, smell, and taste — and to ease Heat when she needs it most."
	)


func prologue_tutorial_social_battery_followup() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"Don't worry about your social battery just yet. More will be explained later!"
	)
