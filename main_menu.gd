extends Control

@onready var _load_slots: Control = $SaveSlotsBrowser


func _ready() -> void:
	CelestialVNState.set_vn_ui_visible(false)
	GameSaveManager.apply_stored_options()
	_load_slots.slot_picked_for_load.connect(_on_load_slot_chosen)
	if OS.is_debug_build():
		var dbg := Button.new()
		dbg.text = "Debug: unlock test state"
		dbg.focus_mode = Control.FOCUS_NONE
		dbg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dbg.offset_left = -280.0
		dbg.offset_top = 12.0
		dbg.offset_right = -12.0
		dbg.offset_bottom = 48.0
		dbg.pressed.connect(_on_debug_playtest_pressed)
		add_child(dbg)


func _on_debug_playtest_pressed() -> void:
	CelestialPlaytestDebug.apply_sampler_playtest_state()


func _input(event: InputEvent) -> void:
	if not _load_slots.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_load_slots.hide_browser()
		get_viewport().set_input_as_handled()


func _on_start_button_pressed() -> void:
	GameSaveManager.pending_load_slot = -1
	get_tree().change_scene_to_file("res://game_scene.tscn")


func _on_load_game_button_pressed() -> void:
	_load_slots.present(false)


func _on_load_slot_chosen(slot_index: int) -> void:
	if not GameSaveManager.has_save_in_slot(slot_index):
		return
	GameSaveManager.prepare_load_from_main_menu(slot_index)
	get_tree().change_scene_to_file("res://game_scene.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
