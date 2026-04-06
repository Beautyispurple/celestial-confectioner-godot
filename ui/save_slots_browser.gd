extends Control

signal slot_picked_for_load(slot_index: int)
signal slot_picked_for_save(slot_index: int)
signal closed

var _is_save_mode: bool = false

@onready var _title_label: Label = $Center/Panel/Margin/VBox/Header/TitleLabel
@onready var _vbox: VBoxContainer = $Center/Panel/Margin/VBox/Scroll/SlotsVBox
@onready var _close_button: Button = $Center/Panel/Margin/VBox/Header/CloseButton


func _ready() -> void:
	_close_button.pressed.connect(hide_browser)
	_build_rows()
	visible = false
	hide()


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
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func(): _on_slot_pressed(idx))
		_vbox.add_child(b)


func _refresh_rows() -> void:
	var i := 0
	for c in _vbox.get_children():
		if c is Button:
			var b := c as Button
			b.text = GameSaveManager.get_slot_display_line(i)
			if _is_save_mode:
				b.disabled = false
			else:
				b.disabled = not GameSaveManager.has_save_in_slot(i)
		i += 1


func _on_slot_pressed(slot_index: int) -> void:
	if _is_save_mode:
		slot_picked_for_save.emit(slot_index)
	else:
		if not GameSaveManager.has_save_in_slot(slot_index):
			return
		slot_picked_for_load.emit(slot_index)
