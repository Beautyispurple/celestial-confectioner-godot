extends Control

signal slot_picked_for_load(slot_index: int)
signal slot_save_confirmed(slot_index: int, display_name: String)
signal closed

var _is_save_mode: bool = false
var _pending_save_slot: int = -1
var _pending_delete_slot: int = -1

@onready var _title_label: Label = $Center/Panel/Margin/VBox/Header/TitleLabel
@onready var _vbox: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/SlotsVBox
@onready var _close_button: Button = $Center/Panel/Margin/VBox/Header/CloseButton

var _save_name_dialog: AcceptDialog = null
var _save_name_edit: LineEdit = null
var _delete_confirm: ConfirmationDialog = null


func _ready() -> void:
	_close_button.pressed.connect(hide_browser)
	_build_rows()
	_ensure_dialogs()
	visible = false
	hide()


func _ensure_dialogs() -> void:
	if _save_name_dialog != null:
		return
	_save_name_dialog = AcceptDialog.new()
	_save_name_dialog.title = "Name your save"
	_save_name_dialog.ok_button_text = "Save"
	_save_name_dialog.min_size = Vector2i(420, 160)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var hint := Label.new()
	hint.text = "Enter a name for this save:"
	_save_name_edit = LineEdit.new()
	_save_name_edit.custom_minimum_size = Vector2(380, 36)
	_save_name_edit.placeholder_text = "Save name"
	vb.add_child(hint)
	vb.add_child(_save_name_edit)
	_save_name_dialog.add_child(vb)
	add_child(_save_name_dialog)
	_save_name_dialog.confirmed.connect(_on_save_name_dialog_confirmed)

	_delete_confirm = ConfirmationDialog.new()
	_delete_confirm.title = "Delete save"
	_delete_confirm.dialog_text = "Delete this save? This cannot be undone."
	_delete_confirm.ok_button_text = "Delete"
	add_child(_delete_confirm)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)


func present(is_save_mode: bool) -> void:
	_is_save_mode = is_save_mode
	_title_label.text = "Save Game" if is_save_mode else "Load Game"
	_refresh_rows()
	visible = true
	show()


func hide_browser() -> void:
	if not visible:
		return
	visible = false
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func _build_rows() -> void:
	for c in _vbox.get_children():
		c.queue_free()
	for i in range(GameSaveManager.SLOT_COUNT):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(520, 44)
		var main := Button.new()
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.alignment = HORIZONTAL_ALIGNMENT_LEFT
		main.custom_minimum_size = Vector2(400, 44)
		var idx := i
		main.pressed.connect(func(): _on_main_slot_pressed(idx))
		var del := Button.new()
		del.text = "Delete"
		del.custom_minimum_size = Vector2(88, 44)
		del.focus_mode = Control.FOCUS_NONE
		del.pressed.connect(func(): _on_delete_slot_pressed(idx))
		del.name = "DeleteBtn"
		row.add_child(main)
		row.add_child(del)
		_vbox.add_child(row)


func _refresh_rows() -> void:
	var i := 0
	for c in _vbox.get_children():
		if c is HBoxContainer:
			var row := c as HBoxContainer
			var main: Button = row.get_child(0) as Button
			var del: Button = row.get_child(1) as Button
			main.text = GameSaveManager.get_slot_display_line(i)
			if _is_save_mode:
				main.disabled = false
				del.visible = false
			else:
				var has_s: bool = GameSaveManager.has_save_in_slot(i)
				main.disabled = not has_s
				del.visible = has_s
		i += 1


func _on_main_slot_pressed(slot_index: int) -> void:
	if _is_save_mode:
		_pending_save_slot = slot_index
		_ensure_dialogs()
		_save_name_edit.text = GameSaveManager.get_slot_default_save_name(slot_index)
		_save_name_dialog.popup_centered()
		return
	if not GameSaveManager.has_save_in_slot(slot_index):
		return
	slot_picked_for_load.emit(slot_index)


func _on_save_name_dialog_confirmed() -> void:
	var slot := _pending_save_slot
	var name := _save_name_edit.text.strip_edges()
	_pending_save_slot = -1
	if slot < 0:
		return
	slot_save_confirmed.emit(slot, name)


func _on_delete_slot_pressed(slot_index: int) -> void:
	if not GameSaveManager.has_save_in_slot(slot_index):
		return
	_pending_delete_slot = slot_index
	_ensure_dialogs()
	_delete_confirm.dialog_text = "Delete save in slot %d? This cannot be undone." % (slot_index + 1)
	_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _pending_delete_slot < 0:
		return
	var err: Error = GameSaveManager.delete_slot(_pending_delete_slot)
	if err != OK:
		push_error("Delete save failed: %s" % error_string(err))
	_pending_delete_slot = -1
	_refresh_rows()
