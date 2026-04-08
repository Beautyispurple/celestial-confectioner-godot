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
		"Breath Tempering is in Marzi's Sampler Box. Use it during the story to help her lower Heat, or from the Main Menu for yourself — slow, steady breathing when the moment asks for it."
	)


func run_sampler_first_open_chain() -> void:
	if _is_sampler_chain_done():
		return
	if not is_breath_tempering_unlocked():
		return
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"As you play, Marzi unlocks different Sampler skills — each one does something different, so pick what fits the moment."
	)
	await _layer.show_plain_tutorial(
		"Sometimes she needs to repeat a skill before it feels like enough. That's okay — skills aren't always one-and-done."
	)
	Dialogic.VAR.set_variable("sampler_tutorial_chain_done", 1)


func _is_sampler_chain_done() -> bool:
	return int(float(str(Dialogic.VAR.get_variable("sampler_tutorial_chain_done", 0)))) != 0


func is_breath_tempering_unlocked() -> bool:
	return int(float(str(Dialogic.VAR.get_variable("breath_tempering_unlocked", 0)))) != 0


func prologue_tutorial_breath_aeration_unlocked() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"Breath Aeration is in the Sampler Box. Follow the inhale/exhale rhythm (no breath-holds) — it trades a little Heat for Social Battery, like swapping sprint for a steady jog."
	)


func prologue_tutorial_sensory_sifting_unlocked() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"Name 5 Things (Sensory Sifting) is in the Sampler Box. It's effortful — one step at a time across seeing, feeling, hearing, smelling, and tasting — and when you finish, it clears Marzi's Heat completely and shields the next 2 Heat (stress hits the shield first). In real life, grounding asks for real attention; the payoff is a steadier body and mind."
	)


func prologue_tutorial_cold_sheen_unlocked() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"Cold Sheen is in the Sampler Box — splash the sink, then finish for a cold \"glacé\" moment. In play it usually drops Heat by 3; at max Heat it only drops by 1 — a sip of cold, not the whole reset. In real life, a quick cold or sensory interrupt often helps most before you're flooded; when you're already at the edge, it can still take the edge off, but it's not a stand-in for deeper support."
	)


func prologue_tutorial_dragee_disposal_unlocked() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"Catch it, Check it, Change it — the Dragee toolkit is in Marzi's Sampler Box (Skills tab). You can run the full flow again: name a thought, decide if it's helpful to keep, and either save it to your Thought shelf (Life tools tab) or work through gather → tilt → trash to let it go. Completing a disposal drops Heat by 3, can count as crisis coping at max Heat, adds your \"what can I do?\" line to the Action log, and gives you three stretches of gentler Social Battery drain the next times Marzi would lose social energy (e.g. a hard phone call). Replay anytime for the same in-game benefits — the exercise is the skill."
	)


func prologue_tutorial_social_battery_followup() -> void:
	await _await_tutorial_layer_ready()
	await _layer.show_plain_tutorial(
		"Social Battery — we'll unpack it later. For now, Heat is the star of the show."
	)
