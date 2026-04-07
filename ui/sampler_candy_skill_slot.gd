class_name SamplerCandySkillSlot
extends Button
## Skill tile styled as a wrapped candy: twist caps + center label band.

@onready var _label: Label = $Margin/HBox/CenterBand/Label
var _text: String = "· · ·"


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, empty)
	_label.text = _text


func set_slot_text(t: String) -> void:
	_text = t
	if is_node_ready() and _label:
		_label.text = t


func set_visual_state(placeholder: bool, interactable: bool) -> void:
	if placeholder:
		modulate = Color(0.42, 0.38, 0.45, 0.72)
	elif interactable:
		modulate = Color.WHITE
	else:
		modulate = Color(0.78, 0.72, 0.82, 1.0)
