extends Node
## Dialogic: `do CelestialMopMinigame.run_closet_figure_eight()` after Huck says "Now you try."

const SCENE := preload("res://ui/figure_eight_mop_minigame.tscn")


func run_closet_figure_eight() -> void:
	await _run_scene("")


func run_solo_aisle_practice() -> void:
	await _run_scene(
		"On the sales floor, trace the loop from Work → Rest → Play — the same figure-eight Huck showed you."
	)


func _run_scene(instruction_override: String) -> void:
	CelestialVNState.begin_blocking_overlay_vn()
	var layer: Node = SCENE.instantiate()
	if not instruction_override.is_empty() and layer.has_method(&"set_instruction_override"):
		layer.call(&"set_instruction_override", instruction_override)
	get_tree().root.add_child(layer)
	if layer.has_signal("finished"):
		await layer.finished
	else:
		await layer.tree_exited
	CelestialVNState.end_blocking_overlay_vn()
