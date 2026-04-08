extends Node
## Debug-only sampler / panic playtest helpers. Release exports: no UI, F9 does nothing.

# When you add a new sampler skill, append its Dialogic `*_unlocked` name here.
const DEBUG_SAMPLER_UNLOCK_VARS: Array[String] = [
	"breath_tempering_unlocked",
	"breath_aeration_unlocked",
	"sensory_sifting_unlocked",
	"cold_sheen_unlocked",
]

const DEBUG_JUMP_OVERLAY_SCENE := preload("res://ui/debug_jump_overlay.tscn")

var _debug_panic_cycle_i: int = 0
var _jump_overlay: CanvasLayer = null
const _DEBUG_JUMP_TOGGLE_KEY := KEY_F7


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		return
	# Debug-only overlay lives under /root for consistent layering.
	_jump_overlay = DEBUG_JUMP_OVERLAY_SCENE.instantiate() as CanvasLayer
	if _jump_overlay != null:
		# /root may be blocked during startup; defer to avoid add_child failure.
		get_tree().root.add_child.call_deferred(_jump_overlay)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		apply_sampler_playtest_state()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == _DEBUG_JUMP_TOGGLE_KEY:
		if _jump_overlay != null and is_instance_valid(_jump_overlay) and _jump_overlay.has_method("toggle_visible"):
			if _jump_overlay.has_method("is_jump_in_progress") and _jump_overlay.call("is_jump_in_progress"):
				get_viewport().set_input_as_handled()
				return
			_jump_overlay.call("toggle_visible")
			get_viewport().set_input_as_handled()


func apply_sampler_playtest_state() -> void:
	if not OS.is_debug_build():
		return
	for var_name in DEBUG_SAMPLER_UNLOCK_VARS:
		Dialogic.VAR.set_variable(var_name, 1)
	var tiers: Array[int] = [0, 6, 10]
	var pp: int = tiers[_debug_panic_cycle_i % tiers.size()]
	_debug_panic_cycle_i += 1
	CelestialVNState.set_panic_points_direct(pp)
	Dialogic.VAR.set_variable("panic_shield", CelestialVNState.PANIC_SHIELD_MAX)
	Dialogic.VAR.set_variable("social_battery", CelestialVNState.SOCIAL_MAX)
	CelestialVNState.refresh_sampler_slots()
