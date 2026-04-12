extends MarginContainer
## 3×2 grid of saved thoughts; tap occupied slot to run disposal mini.

const _CHIP_SCENE := preload("res://ui/dragee_thought_chip.tscn")

@onready var _grid: GridContainer = $VBox/Grid


func _ready() -> void:
	if not CelestialDrageeDisposal.shelf_changed.is_connected(_deferred_refresh):
		CelestialDrageeDisposal.shelf_changed.connect(_deferred_refresh)
	_rebuild()


func _deferred_refresh() -> void:
	call_deferred("_rebuild")


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var shelf: Array = CelestialDrageeDisposal.shelf
	for i in range(6):
		var chip: DrageeThoughtChip = _CHIP_SCENE.instantiate() as DrageeThoughtChip
		chip.custom_minimum_size = Vector2(108, 76)
		chip.draggable = false
		if i < shelf.size():
			var ent: Variant = shelf[i]
			var t := ""
			if ent is Dictionary:
				t = str((ent as Dictionary).get("thought_text", ""))
			chip.set_thought_text(_truncate(t, 32))
			chip.tooltip_text = t
			var idx: int = i
			chip.activated.connect(_on_occupied_pressed.bind(idx))
		else:
			chip.set_placeholder_empty()
		_grid.add_child(chip)


func _truncate(s: String, max_chars: int) -> String:
	if s.length() <= max_chars:
		return s
	return s.substr(0, max_chars - 1) + "…"


func _on_occupied_pressed(slot_index: int) -> void:
	await CelestialDrageeDisposal.run_from_shelf_slot(slot_index)
	_rebuild()
