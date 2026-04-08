extends MarginContainer
## Newest-first action lines from disposal completions; checkboxes persist.

@onready var _list: VBoxContainer = $VBox/Scroll/List


func _ready() -> void:
	if not CelestialDrageeDisposal.action_log_changed.is_connected(_deferred_refresh):
		CelestialDrageeDisposal.action_log_changed.connect(_deferred_refresh)
	_rebuild()


func _deferred_refresh() -> void:
	call_deferred("_rebuild")


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var entries: Array = CelestialDrageeDisposal.action_log
	for i in range(entries.size()):
		var entry: Variant = entries[i]
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry as Dictionary
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var cb := CheckBox.new()
		cb.button_pressed = bool(d.get("done", false))
		var idx: int = i
		cb.toggled.connect(func(on: bool) -> void: CelestialDrageeDisposal.set_action_log_done(idx, on))
		var lbl := Label.new()
		var when: String = str(d.get("created_at", ""))
		var tx: String = str(d.get("text", ""))
		lbl.text = tx if when.is_empty() else "[%s] %s" % [when, tx]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(cb)
		row.add_child(lbl)
		_list.add_child(row)
