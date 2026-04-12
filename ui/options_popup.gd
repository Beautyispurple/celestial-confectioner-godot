extends Control

signal closed

@onready var _fullscreen: CheckBox = $Center/Panel/Margin/VBox/FullscreenCheck
@onready var _volume: HSlider = $Center/Panel/Margin/VBox/VolumeSlider
@onready var _music_mute: CheckBox = $Center/Panel/Margin/VBox/MusicRow/MusicMuteCheck
@onready var _music_volume: HSlider = $Center/Panel/Margin/VBox/MusicRow/MusicVolumeSlider
@onready var _voice_mute: CheckBox = $Center/Panel/Margin/VBox/VoiceRow/VoiceMuteCheck
@onready var _voice_volume: HSlider = $Center/Panel/Margin/VBox/VoiceRow/VoiceVolumeSlider
@onready var _close_button: Button = $Center/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	_close_button.pressed.connect(_apply_and_close)
	visible = false
	hide()


func present() -> void:
	var o: Dictionary = GameSaveManager.load_options()
	_fullscreen.button_pressed = o["fullscreen"] as bool
	_setup_db_slider(_volume, o["master_db"] as float)
	_setup_db_slider(_music_volume, o["music_db"] as float)
	_setup_db_slider(_voice_volume, o["voice_db"] as float)
	_music_mute.button_pressed = o["music_muted"] as bool
	_voice_mute.button_pressed = o["voice_muted"] as bool
	visible = true
	show()


func _setup_db_slider(slider: HSlider, db: float) -> void:
	slider.min_value = -40.0
	slider.max_value = 0.0
	slider.step = 1.0
	slider.value = db


func hide_options() -> void:
	if not visible:
		return
	visible = false
	hide()
	closed.emit()


func _apply_and_close() -> void:
	var fs := _fullscreen.button_pressed
	var db := _volume.value as float
	var mdb := _music_volume.value as float
	var vdb := _voice_volume.value as float
	var mm := _music_mute.button_pressed
	var vm := _voice_mute.button_pressed
	GameSaveManager.save_options(fs, db, mdb, vdb, mm, vm)
	GameSaveManager.apply_options(fs, db, mdb, vdb, mm, vm)
	hide_options()
