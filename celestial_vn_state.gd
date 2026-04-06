extends Node
## Autoload: panic/social clamping, relationship labels, toast queue, crisis gating, tier queries.

const PANIC_MAX := 10
const SOCIAL_MAX := 10

const EXCLUDED_RELATIONSHIP_POINTS: Array[String] = ["panic_points", "peace_points"]

signal panic_tier_changed(tier: int)
signal crisis_coping_resolved()
signal toast_requested(label: String, signed_delta: int)

enum PanicTier {
	NORMAL,
	WARNING,
	LOCK_RATIONAL,
	CRISIS,
}

var _clamping: bool = false
var _needs_crisis_coping: bool = false
## Last applied values for panic/social (set_variable only emits variable_changed, not variable_was_set).
var _panic_points_cache: int = 0
var _social_battery_cache: int = 0
var _toast_queue: Array[Dictionary] = []
var _toast_runner_active: bool = false

var _vn_ui_visible_desired: bool = false
var _sampler_blocking_vn: bool = false

@onready var _toast_layer: CanvasLayer = null
var _hud_layer: CanvasLayer = null
var _panic_layer: CanvasLayer = null
var _sampler_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	if not Dialogic.VAR.variable_changed.is_connected(_on_variable_changed_clamped_stats):
		Dialogic.VAR.variable_changed.connect(_on_variable_changed_clamped_stats)
	if not Dialogic.VAR.variable_was_set.is_connected(_on_variable_was_set):
		Dialogic.VAR.variable_was_set.connect(_on_variable_was_set)
	if not Dialogic.Inputs.dialogic_action_priority.is_connected(_on_dialogic_action_priority):
		Dialogic.Inputs.dialogic_action_priority.connect(_on_dialogic_action_priority)
	var toast_scene: PackedScene = load("res://ui/variable_toast_layer.tscn") as PackedScene
	if toast_scene:
		_toast_layer = toast_scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_toast_layer)
	var hud_scene: PackedScene = load("res://ui/celestial_hud_layer.tscn") as PackedScene
	if hud_scene:
		_hud_layer = hud_scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_hud_layer)
	var panic_scene: PackedScene = load("res://ui/celestial_panic_overlay.tscn") as PackedScene
	if panic_scene:
		_panic_layer = panic_scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_panic_layer)
	var sampler_scene: PackedScene = load("res://ui/sampler_box.tscn") as PackedScene
	if sampler_scene:
		_sampler_layer = sampler_scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_sampler_layer)
	_panic_points_cache = get_panic_points()
	_social_battery_cache = get_social_battery()
	_apply_vn_ui_visibility()


func set_vn_ui_visible(v: bool) -> void:
	_vn_ui_visible_desired = v
	_apply_vn_ui_visibility()


func _apply_vn_ui_visibility() -> void:
	if _panic_layer:
		_panic_layer.visible = _vn_ui_visible_desired
	if _hud_layer:
		_hud_layer.visible = _vn_ui_visible_desired
		_hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS if _vn_ui_visible_desired else Node.PROCESS_MODE_DISABLED
	if _sampler_layer:
		_sampler_layer.visible = _vn_ui_visible_desired
		_sampler_layer.process_mode = Node.PROCESS_MODE_ALWAYS if _vn_ui_visible_desired else Node.PROCESS_MODE_DISABLED
		if not _vn_ui_visible_desired and _sampler_layer.has_method("reset_for_menu"):
			_sampler_layer.reset_for_menu()


func set_sampler_blocking_vn(v: bool) -> void:
	_sampler_blocking_vn = v


func is_sampler_blocking_vn() -> bool:
	return _sampler_blocking_vn


func get_panic_points() -> int:
	return int(float(Dialogic.VAR.get_variable("panic_points", 0)))


func get_social_battery() -> int:
	return int(float(Dialogic.VAR.get_variable("social_battery", 0)))


func get_panic_tier() -> int:
	var p: int = get_panic_points()
	if p >= 10:
		return PanicTier.CRISIS
	if p >= 6:
		return PanicTier.LOCK_RATIONAL
	return PanicTier.NORMAL


func is_crisis_advance_blocked() -> bool:
	return get_panic_tier() == PanicTier.CRISIS and _needs_crisis_coping


func mark_crisis_coping_used() -> void:
	if not _needs_crisis_coping:
		return
	_needs_crisis_coping = false
	crisis_coping_resolved.emit()


func notify_sampler_coping_completed() -> void:
	mark_crisis_coping_used()


static func relationship_display_name(var_name: String) -> String:
	var base: String = var_name.trim_suffix("_points")
	if base.is_empty():
		return var_name
	return base.capitalize()


static func is_rational_response(choice_info: Dictionary) -> bool:
	return str(choice_info.get("response_kind", "")).to_lower() == "rational"


func _on_variable_changed_clamped_stats(info: Dictionary) -> void:
	if _clamping:
		return
	var v: String = str(info.get("variable", ""))
	if v != "panic_points" and v != "social_battery":
		return
	var orig_f: float = float(_panic_points_cache) if v == "panic_points" else float(_social_battery_cache)
	_handle_clamped_stat(
		{"variable": v, "orig_value": orig_f, "new_value": info.get("new_value")}
	)


func _on_variable_was_set(info: Dictionary) -> void:
	if _clamping:
		return

	var v: String = str(info.get("variable", ""))

	if v.ends_with("_points") and v not in EXCLUDED_RELATIONSHIP_POINTS:
		_handle_relationship_points(info)


func _handle_clamped_stat(info: Dictionary) -> void:
	var v: String = str(info.get("variable", ""))
	var orig_f: float = _to_float_safe(info.get("orig_value"))
	var new_f: float = _to_float_safe(info.get("new_value"))
	var mx: int = PANIC_MAX if v == "panic_points" else SOCIAL_MAX
	var target: int = clampi(int(round(new_f)), 0, mx)

	if int(round(new_f)) != target:
		_clamping = true
		Dialogic.VAR.set_variable(v, target)
		_clamping = false
		new_f = float(target)

	var delta_i: int = int(round(new_f - orig_f))
	if delta_i == 0:
		pass
	else:
		var prev_tier: int = _tier_from_points(int(round(orig_f)))
		var next_tier: int = _tier_from_points(int(round(new_f)))
		if next_tier == PanicTier.CRISIS and prev_tier != PanicTier.CRISIS:
			_needs_crisis_coping = true
		if next_tier < PanicTier.CRISIS:
			_needs_crisis_coping = false
		if prev_tier != next_tier:
			panic_tier_changed.emit(next_tier)
			call_deferred("_refresh_dialogic_choices_if_any")

		if v == "panic_points":
			_enqueue_toast("Heat", delta_i)
		else:
			_enqueue_toast("Social Battery", delta_i)

	if v == "panic_points":
		_panic_points_cache = get_panic_points()
	else:
		_social_battery_cache = get_social_battery()


func _handle_relationship_points(info: Dictionary) -> void:
	var v: String = str(info.get("variable", ""))
	var nv = info.get("new_value")
	if nv is String and str(nv).strip_edges().is_empty():
		return
	var orig_f: float = _to_float_safe(info.get("orig_value"))
	var new_f: float = _to_float_safe(info.get("new_value"))
	if not str(info.get("new_value", "")).is_valid_float() and typeof(info.get("new_value")) != TYPE_FLOAT and typeof(info.get("new_value")) != TYPE_INT:
		return
	var delta_i: int = int(round(new_f - orig_f))
	if delta_i == 0:
		return
	var display: String = relationship_display_name(v)
	_enqueue_toast(display, delta_i)


func _to_float_safe(x: Variant) -> float:
	if x == null:
		return 0.0
	if typeof(x) in [TYPE_FLOAT, TYPE_INT]:
		return float(x)
	var s := str(x)
	if s.is_valid_float():
		return float(s)
	return 0.0


func _tier_from_points(p: int) -> int:
	if p >= 10:
		return PanicTier.CRISIS
	if p >= 6:
		return PanicTier.LOCK_RATIONAL
	return PanicTier.NORMAL


func _enqueue_toast(label: String, signed_delta: int) -> void:
	_toast_queue.append({"label": label, "delta": signed_delta})
	if not _toast_runner_active:
		_run_toast_queue()


func _run_toast_queue() -> void:
	_toast_runner_active = true
	while not _toast_queue.is_empty():
		var item: Dictionary = _toast_queue.pop_front()
		toast_requested.emit(str(item["label"]), int(item["delta"]))
		if _toast_layer and _toast_layer.has_method("show_toast"):
			await _toast_layer.show_toast(str(item["label"]), int(item["delta"]))
	_toast_runner_active = false


func _on_dialogic_action_priority() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var hovered: Control = vp.gui_get_hovered_control()
	if is_sampler_blocking_vn() and hovered and _control_is_under_sampler(hovered):
		Dialogic.Inputs.action_was_consumed = true
		return
	if not is_crisis_advance_blocked():
		return
	if hovered and _control_is_under_sampler(hovered):
		return
	Dialogic.Inputs.action_was_consumed = true


func _control_is_under_sampler(ctrl: Control) -> bool:
	var n: Node = ctrl
	while n:
		if n.is_in_group("celestial_sampler_ui"):
			return true
		n = n.get_parent()
	return false


func _refresh_dialogic_choices_if_any() -> void:
	if not is_instance_valid(Dialogic):
		return
	if Dialogic.current_state != Dialogic.States.AWAITING_CHOICE:
		return
	Dialogic.Choices.show_current_question(true)


func choice_should_lock(choice_info: Dictionary) -> bool:
	var tier: int = get_panic_tier()
	if tier < PanicTier.LOCK_RATIONAL:
		return false
	var rational: bool = is_rational_response(choice_info)
	if tier == PanicTier.CRISIS:
		return true
	return rational
