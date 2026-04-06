extends Node
## Dialogic: `do BoxBreathingMinigame.run_post_guide_breathing_cycles()` after Chai's guided breath.

const OVERLAY_SCENE := preload("res://ui/box_breathing_overlay.tscn")

var _overlay: CanvasLayer


func _ready() -> void:
	_overlay = OVERLAY_SCENE.instantiate()
	_overlay.visible = false
	get_tree().root.call_deferred("add_child", _overlay)


func run_post_guide_breathing_cycles() -> void:
	if _overlay and _overlay.has_method("run_three_cycles"):
		await _overlay.run_three_cycles()
