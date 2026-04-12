extends DialogicNode_ChoiceButton

const LOCK_TOOLTIP := "I need to use a skill from Marzi's Sampler Box before I can do this..."

@onready var _glass: ColorRect = $GlassOverlay


func _load_info(choice_info: Dictionary) -> void:
	super._load_info(choice_info)
	var lock: bool = CelestialVNState.choice_should_lock(choice_info)
	if lock:
		disabled = true
		_glass.visible = true
		tooltip_text = LOCK_TOOLTIP
	else:
		_glass.visible = false
		if not choice_info.get("disabled", false):
			var ht: String = str(choice_info.get("heat_tooltip", "")).strip_edges()
			tooltip_text = ht
