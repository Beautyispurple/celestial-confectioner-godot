extends Control

signal closed

@onready var _fullscreen: CheckBox = $Center/Panel/Margin/VBox/FullscreenCheck
@onready var _volume: HSlider = $Center/Panel/Margin/VBox/VolumeSlider
@onready var _close_button: Button = $Center/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	_close_button.pressed.connect(_apply_and_close)
	visible = false
	hide()


func present() -> void:
	var o: Dictionary = GameSaveManager.load_options()
	_fullscreen.button_pressed = o["fullscreen"] as bool
	_volume.min_value = -40.0
	_volume.max_value = 0.0
	_volume.step = 1.0
	_volume.value = o["master_db"] as float
	visible = true
	show()


func hide_options() -> void:
	if not visible:
		return
	visible = false
	hide()
	closed.emit()


func _apply_and_close() -> void:
	var fs := _fullscreen.button_pressed
	var db := _volume.value as float
	GameSaveManager.save_options(fs, db)
	GameSaveManager.apply_options(fs, db)
	hide_options()
