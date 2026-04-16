class_name OptionsPopup
extends Control

signal closed

@onready var _master: HSlider = $Center/Panel/Margin/VBox/TabContainer/Audio/MasterSlider
@onready var _music_mute: CheckBox = $Center/Panel/Margin/VBox/TabContainer/Audio/MusicRow/MusicMuteCheck
@onready var _music_volume: HSlider = $Center/Panel/Margin/VBox/TabContainer/Audio/MusicRow/MusicVolumeSlider
@onready var _voice_mute: CheckBox = $Center/Panel/Margin/VBox/TabContainer/Audio/VoiceRow/VoiceMuteCheck
@onready var _voice_volume: HSlider = $Center/Panel/Margin/VBox/TabContainer/Audio/VoiceRow/VoiceVolumeSlider

@onready var _fullscreen: CheckBox = $Center/Panel/Margin/VBox/TabContainer/Video/FullscreenCheck
@onready var _vsync: CheckBox = $Center/Panel/Margin/VBox/TabContainer/Video/VSyncCheck

@onready var _text_speed: HSlider = $Center/Panel/Margin/VBox/TabContainer/Gameplay/TextSpeedSlider

@onready var _ui_scale: HSlider = $Center/Panel/Margin/VBox/TabContainer/Accessibility/UIScaleSlider
@onready var _high_contrast: CheckBox = $Center/Panel/Margin/VBox/TabContainer/Accessibility/HighContrastCheck
@onready var _reduce_motion: CheckBox = $Center/Panel/Margin/VBox/TabContainer/Accessibility/ReduceMotionCheck
@onready var _colorblind: OptionButton = $Center/Panel/Margin/VBox/TabContainer/Accessibility/ColorblindOption
@onready var _colorblind_strength: HSlider = $Center/Panel/Margin/VBox/TabContainer/Accessibility/ColorblindStrengthSlider

@onready var _close_button: Button = $Center/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	_close_button.pressed.connect(_apply_and_close)
	_setup_colorblind_options()
	visible = false
	hide()


func _setup_colorblind_options() -> void:
	_colorblind.clear()
	_colorblind.add_item("Off", 0)
	_colorblind.add_item("Deuteranopia", 1)
	_colorblind.add_item("Protanopia", 2)
	_colorblind.add_item("Tritanopia", 3)


func present() -> void:
	var o: Dictionary = GameSaveManager.load_options()
	_fullscreen.button_pressed = o["fullscreen"] as bool
	_vsync.button_pressed = o["vsync"] as bool
	_setup_db_slider(_master, o["master_db"] as float)
	_setup_db_slider(_music_volume, o["music_db"] as float)
	_setup_db_slider(_voice_volume, o["voice_db"] as float)
	_music_mute.button_pressed = o["music_muted"] as bool
	_voice_mute.button_pressed = o["voice_muted"] as bool
	_text_speed.min_value = 0.005
	_text_speed.max_value = 0.12
	_text_speed.step = 0.001
	_text_speed.value = clampf(o["text_letter_speed"] as float, 0.005, 0.12)
	_ui_scale.min_value = 0.75
	_ui_scale.max_value = 1.5
	_ui_scale.step = 0.05
	_ui_scale.value = clampf(o["ui_scale"] as float, 0.75, 1.5)
	_high_contrast.button_pressed = o["high_contrast"] as bool
	_reduce_motion.button_pressed = o["reduce_motion"] as bool
	var preset: int = clampi(int(o["colorblind_preset"]), 0, 3)
	for i in range(_colorblind.item_count):
		if _colorblind.get_item_id(i) == preset:
			_colorblind.select(i)
			break
	_colorblind_strength.min_value = 0.0
	_colorblind_strength.max_value = 1.0
	_colorblind_strength.step = 0.05
	_colorblind_strength.value = clampf(o["colorblind_strength"] as float, 0.0, 1.0)
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
	var preset_id: int = 0
	if _colorblind.selected >= 0:
		preset_id = _colorblind.get_item_id(_colorblind.selected)
	var o: Dictionary = {
		"fullscreen": _fullscreen.button_pressed,
		"vsync": _vsync.button_pressed,
		"master_db": _master.value as float,
		"music_db": _music_volume.value as float,
		"voice_db": _voice_volume.value as float,
		"music_muted": _music_mute.button_pressed,
		"voice_muted": _voice_mute.button_pressed,
		"text_letter_speed": _text_speed.value as float,
		"ui_scale": _ui_scale.value as float,
		"high_contrast": _high_contrast.button_pressed,
		"reduce_motion": _reduce_motion.button_pressed,
		"colorblind_preset": preset_id,
		"colorblind_strength": _colorblind_strength.value as float,
	}
	GameSaveManager.save_options_dict(o)
	GameSaveManager.apply_stored_options()
	hide_options()
