extends Node
## Dialogic: `do BoxBreathingMinigame.run_post_guide_breathing_cycles()` after Chai's guided breath.

const OVERLAY_SCENE := preload("res://ui/box_breathing_overlay.tscn")

var _layer: CanvasLayer
var _overlay: Control


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 16
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OVERLAY_SCENE.instantiate() as Control
	_overlay.visible = false
	_layer.add_child(_overlay)
	get_tree().root.call_deferred("add_child", _layer)


func run_post_guide_breathing_cycles() -> void:
	if _overlay and _overlay.has_method("run_three_cycles"):
		await _overlay.run_three_cycles()
