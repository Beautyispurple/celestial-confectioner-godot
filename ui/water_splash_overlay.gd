extends Control
## Full-viewport splash flash; parent under SamplerBox CanvasLayer (not SlidePanel). Click-through.

func _ready() -> void:
	add_to_group("celestial_water_splash")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func play_splash() -> void:
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	modulate.a = 0.85
	tw.tween_property(self, "modulate:a", 0.0, 0.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	visible = false
	modulate = Color.WHITE
