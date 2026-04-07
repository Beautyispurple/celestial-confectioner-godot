extends Node
## Dialogic: `do CelestialMopMinigame.run_closet_figure_eight()` after Huck says "Now you try."

const SCENE := preload("res://ui/figure_eight_mop_minigame.tscn")


func run_closet_figure_eight() -> void:
	CelestialVNState.begin_blocking_overlay_vn()
	var layer: Node = SCENE.instantiate()
	get_tree().root.add_child(layer)
	if layer.has_signal("finished"):
		await layer.finished
	else:
		await layer.tree_exited
	CelestialVNState.end_blocking_overlay_vn()
