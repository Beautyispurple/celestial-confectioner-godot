extends CanvasLayer

@onready var _dim: ColorRect = $DimRect
@onready var _main_panel: PanelContainer = $Center/MainPanel
@onready var _save_button: Button = $Center/MainPanel/Margin/VBox/SaveButton
@onready var _load_button: Button = $Center/MainPanel/Margin/VBox/LoadButton
@onready var _options_button: Button = $Center/MainPanel/Margin/VBox/OptionsButton
@onready var _main_menu_button: Button = $Center/MainPanel/Margin/VBox/MainMenuButton
@onready var _exit_button: Button = $Center/MainPanel/Margin/VBox/ExitButton
@onready var _slots: Control = $SaveSlotsBrowser
@onready var _options: Control = $OptionsPopup
@onready var _quit_confirm: ConfirmationDialog = $QuitConfirm
@onready var _main_menu_confirm: ConfirmationDialog = $MainMenuConfirm

var _menu_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_slots.slot_picked_for_load.connect(_on_pause_load_slot)
	_slots.slot_save_confirmed.connect(_on_pause_save_confirmed)
	_slots.closed.connect(_on_slots_closed)
	_options.closed.connect(_on_options_closed)
	_quit_confirm.confirmed.connect(_on_quit_confirmed)
	_main_menu_confirm.confirmed.connect(_on_main_menu_confirmed)
	hide_menu()


func hide_menu() -> void:
	_menu_open = false
	visible = false
	_slots.hide_browser()
	_options.hide_options()
	_main_panel.visible = true
	get_tree().paused = false


func open_menu() -> void:
	_menu_open = true
	visible = true
	_main_panel.show()
	_main_panel.visible = true
	_dim.visible = true
	get_tree().paused = true


func _on_save_pressed() -> void:
	_main_panel.visible = false
	_slots.present(true)


func _on_load_pressed() -> void:
	_main_panel.visible = false
	_slots.present(false)


func _on_options_pressed() -> void:
	_main_panel.visible = false
	_options.present()


func _on_main_menu_pressed() -> void:
	_main_menu_confirm.popup_centered()


func _on_main_menu_confirmed() -> void:
	hide_menu()
	_go_to_main_menu_after_dialogic_cleanup()


## Dialogic attaches its layout under /root, not under the game scene, so it survives
## change_scene unless we end the timeline and remove that layout first.
func _go_to_main_menu_after_dialogic_cleanup() -> void:
	await Dialogic.end_timeline(true)
	if Dialogic.Styles.has_active_layout_node():
		var layout: Node = Dialogic.Styles.get_layout_node()
		if is_instance_valid(layout) and layout.is_inside_tree():
			layout.get_parent().remove_child(layout)
			layout.queue_free()
		if get_tree().has_meta("dialogic_layout_node"):
			get_tree().remove_meta("dialogic_layout_node")
	GameSaveManager.pending_load_slot = -1
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _on_exit_pressed() -> void:
	_quit_confirm.popup_centered()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_pause_save_confirmed(slot_index: int, display_name: String) -> void:
	var err: Error = GameSaveManager.save_to_slot(slot_index, display_name)
	if err != OK:
		push_error("Save failed: %s" % error_string(err))
	_slots.hide_browser()
	_main_panel.visible = true


func _on_pause_load_slot(slot_index: int) -> void:
	var err: Error = GameSaveManager.load_from_slot(slot_index)
	if err == OK:
		await get_tree().process_frame
		await get_tree().process_frame
		GameSaveManager.restore_extras_after_load(slot_index)
	else:
		push_error("Load failed: %s" % error_string(err))
	_slots.hide_browser()
	hide_menu()


func _on_slots_closed() -> void:
	_main_panel.visible = true


func _on_options_closed() -> void:
	_main_panel.visible = true


func handle_escape_toggle() -> bool:
	if _quit_confirm.visible:
		return false
	if _main_menu_confirm.visible:
		return false
	if _options.visible:
		_options._apply_and_close()
		return true
	if _slots.is_open():
		_slots.hide_browser()
		_main_panel.visible = true
		return true
	if _menu_open:
		hide_menu()
		return true
	open_menu()
	return true


func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ESCAPE:
		return
	if _quit_confirm.visible:
		return
	if _main_menu_confirm.visible:
		return
	if handle_escape_toggle():
		get_viewport().set_input_as_handled()
