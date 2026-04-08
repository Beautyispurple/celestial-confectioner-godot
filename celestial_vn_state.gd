extends Node
## Autoload: panic/social clamping, relationship labels, toast queue, crisis gating, tier queries.

const PANIC_MAX := 10
const SOCIAL_MAX := 10
const PANIC_SHIELD_MAX := 2

const EXCLUDED_RELATIONSHIP_POINTS: Array[String] = ["panic_points", "peace_points"]

## Dev-only: warn if relationship toast delta looks like string-concat corruption.
const _RELATIONSHIP_TOAST_DELTA_WARN_ABS := 50
const _RELATIONSHIP_TOAST_VALUE_STR_LEN_WARN := 8

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
var _panic_shield_cache: int = 0
var _shield_clamping: bool = false
var _toast_queue: Array[Dictionary] = []
var _toast_runner_active: bool = false

var _vn_ui_visible_desired: bool = false
var _sampler_blocking_vn: bool = false
## Refcount: mop minigame, bag panel, etc. Dialogic advance blocked while > 0.
var _blocking_overlay_refcount: int = 0

## Refcount: hide Dialogic chrome + heat warning + bag during dragee / fullscreen minigame prompts.
var _minigame_modal_refcount: int = 0
var _minigame_modal_saved: Array[Dictionary] = []

@onready var _toast_layer: CanvasLayer = null
var _hud_layer: CanvasLayer = null
var _panic_layer: CanvasLayer = null
var _sampler_layer: CanvasLayer = null
var _heat_warning_layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	_merge_missing_dialogic_variables_from_project_defaults()
	_coerce_numeric_dialogic_vars()
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
	var heat_warn_scene: PackedScene = load("res://ui/heat_warning_layer.tscn") as PackedScene
	if heat_warn_scene:
		_heat_warning_layer = heat_warn_scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_heat_warning_layer)
	_panic_points_cache = get_panic_points()
	_social_battery_cache = get_social_battery()
	_panic_shield_cache = get_panic_shield()
	_apply_vn_ui_visibility()
	ensure_sampler_unlock_migrations()
	refresh_sampler_slots()


## If a variable exists in Project Settings → dialogic → variables but not in runtime state, sets fail silently in timelines.
## Call after Dialogic.Save.load: saved games may omit newer variable keys; merge restores them so set/get works.
func resync_dialogic_variables_from_project_defaults() -> void:
	_merge_missing_dialogic_variables_from_project_defaults()
	_coerce_numeric_dialogic_vars()


func _merge_missing_dialogic_variables_from_project_defaults() -> void:
	var defs: Dictionary = ProjectSettings.get_setting("dialogic/variables", {}) as Dictionary
	if defs.is_empty():
		return
	if not Dialogic.current_state_info.has("variables"):
		Dialogic.current_state_info["variables"] = {}
	var vars: Dictionary = Dialogic.current_state_info["variables"] as Dictionary
	for k in defs.keys():
		if not vars.has(k):
			var v: Variant = defs[k]
			if v is Dictionary:
				vars[k] = (v as Dictionary).duplicate(true)
			else:
				vars[k] = v


## Old saves may still store Dialogic numbers as strings; coerce to float so math/toasts stay correct.
## Mutates state dict only (no signals) so load does not enqueue toasts.
func _coerce_numeric_dialogic_vars() -> void:
	if not Dialogic.current_state_info.has("variables"):
		return
	var vars: Dictionary = Dialogic.current_state_info["variables"] as Dictionary
	for k in vars.keys():
		var val: Variant = vars[k]
		if val is Dictionary:
			continue
		if typeof(val) != TYPE_STRING:
			continue
		var s := str(val).strip_edges()
		if not s.is_valid_float():
			continue
		vars[k] = float(s)


func set_vn_ui_visible(v: bool) -> void:
	_vn_ui_visible_desired = v
	_apply_vn_ui_visibility()


func _apply_vn_ui_visibility() -> void:
	if _panic_layer:
		_panic_layer.visible = _vn_ui_visible_desired
	if _heat_warning_layer:
		_heat_warning_layer.visible = _vn_ui_visible_desired
		_heat_warning_layer.process_mode = Node.PROCESS_MODE_ALWAYS if _vn_ui_visible_desired else Node.PROCESS_MODE_DISABLED
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


func begin_blocking_overlay_vn() -> void:
	_blocking_overlay_refcount += 1


func end_blocking_overlay_vn() -> void:
	_blocking_overlay_refcount = maxi(0, _blocking_overlay_refcount - 1)


func is_blocking_overlay_vn() -> bool:
	return _blocking_overlay_refcount > 0


func begin_minigame_modal_focus() -> void:
	_minigame_modal_refcount += 1
	if _minigame_modal_refcount > 1:
		return
	_minigame_modal_saved.clear()
	if Dialogic.Styles.has_active_layout_node():
		var layout: Node = Dialogic.Styles.get_layout_node() as Node
		if layout != null:
			for node_name in ["VN_ChoiceLayer", "TextboxWithSpeakerPortrait", "TextInputLayer"]:
				var ctrl: Node = layout.find_child(node_name, true, false)
				if ctrl is Control:
					var ct: Control = ctrl as Control
					_minigame_modal_saved.append({"n": ct, "v": ct.visible})
					ct.visible = false
	if _heat_warning_layer != null:
		_minigame_modal_saved.append({"n": _heat_warning_layer, "v": _heat_warning_layer.visible})
		_heat_warning_layer.visible = false
	if _hud_layer != null:
		var bag: Node = _hud_layer.find_child("MarziBagPanel", true, false)
		if bag is Control:
			var bc: Control = bag as Control
			_minigame_modal_saved.append({"n": bc, "v": bc.visible})
			bc.visible = false


func end_minigame_modal_focus() -> void:
	_minigame_modal_refcount = maxi(0, _minigame_modal_refcount - 1)
	if _minigame_modal_refcount > 0:
		return
	for item in _minigame_modal_saved:
		var ct: Control = item.get("n") as Control
		if is_instance_valid(ct):
			ct.visible = bool(item.get("v", true))
	_minigame_modal_saved.clear()


## Use for social battery loss so dragee disposal buff (50% for N drains) can apply.
func apply_social_drain(raw_loss: int) -> void:
	if raw_loss <= 0:
		return
	var dr: Node = get_node_or_null("/root/CelestialDrageeDisposal")
	var eff: int = raw_loss
	if dr != null and dr.has_method("consume_social_buff_if_any"):
		eff = int(dr.call("consume_social_buff_if_any", raw_loss))
	apply_direct_social_delta(-eff)


func refresh_sampler_slots() -> void:
	if _sampler_layer != null and _sampler_layer.has_method("refresh_slot_visibility"):
		_sampler_layer.refresh_slot_visibility()


## Load-time hook: never clear cold_sheen_unlocked; a flag set in older builds (e.g. with Breath Tempering) stays valid.
## Cold Sheen is no longer granted from Breath Tempering alone — new unlock is the bathroom water path in the prologue.
func ensure_sampler_unlock_migrations() -> void:
	CelestialDrageeDisposal.apply_save_migration_for_sampler_unlock()


func get_panic_points() -> int:
	return int(float(Dialogic.VAR.get_variable("panic_points", 0)))


func get_social_battery() -> int:
	return int(float(Dialogic.VAR.get_variable("social_battery", 0)))


func get_panic_shield() -> int:
	return clampi(int(float(Dialogic.VAR.get_variable("panic_shield", 0))), 0, PANIC_SHIELD_MAX)


## Stress events only: absorbs into panic_shield before raising panic_points.
func apply_stress_panic_delta(delta: int) -> void:
	if delta <= 0:
		return
	var pp: int = get_panic_points()
	var sh: int = get_panic_shield()
	var absorb: int = mini(delta, sh)
	var new_sh: int = sh - absorb
	var hits_panic: int = delta - absorb
	if new_sh != sh:
		_set_panic_shield_clamped(new_sh)
	var new_pp: int = clampi(pp + hits_panic, 0, PANIC_MAX)
	if new_pp != pp:
		Dialogic.VAR.set_variable("panic_points", new_pp)


## Direct panic change (rewards, skills, narrative sets). Does not use shield.
func apply_direct_panic_delta(delta: int) -> void:
	var pp: int = get_panic_points()
	Dialogic.VAR.set_variable("panic_points", clampi(pp + delta, 0, PANIC_MAX))


## Direct social battery change (inventory, rewards). Clamped like narrative sets.
func apply_direct_social_delta(delta: int) -> void:
	var sb: int = get_social_battery()
	Dialogic.VAR.set_variable("social_battery", clampi(sb + delta, 0, SOCIAL_MAX))


func set_panic_points_direct(value: int) -> void:
	Dialogic.VAR.set_variable("panic_points", clampi(value, 0, PANIC_MAX))


func set_panic_shield_direct(value: int) -> void:
	_set_panic_shield_clamped(value)


func _set_panic_shield_clamped(v: int) -> void:
	var t: int = clampi(v, 0, PANIC_SHIELD_MAX)
	if t == _panic_shield_cache:
		return
	_shield_clamping = true
	Dialogic.VAR.set_variable("panic_shield", t)
	_shield_clamping = false
	_panic_shield_cache = t


## Dialogic: one-time +2 panic when Breath Aeration unlocks (clamped to max).
func grant_breath_aeration_unlock_panic_if_needed() -> void:
	if int(float(str(Dialogic.VAR.get_variable("breath_aeration_panic_grant_done", 0)))) != 0:
		return
	Dialogic.VAR.set_variable("breath_aeration_panic_grant_done", 1)
	apply_direct_panic_delta(2)


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


## Clears crisis advance gating (same as Breath Tempering success). Cold Sheen calls this only when
## panic was below crisis before the skill (see apply_cold_sheen_effect): in crisis it does not
## invoke this, so it does not mirror Temper’s explicit coping clear—though dropping Heat below 10
## may still clear gating via normal panic variable handling.
func notify_sampler_coping_completed() -> void:
	mark_crisis_coping_used()


## Cold finish: stronger when Heat (panic) is below max; at crisis (10) only a small dip (−1).
## Returns true if the crisis branch ran (for UI copy). Non-crisis: −3 Heat and notify (Temper-like clear).
func apply_cold_sheen_effect() -> bool:
	var p: int = get_panic_points()
	if p >= PANIC_MAX:
		apply_direct_panic_delta(-1)
		return true
	apply_direct_panic_delta(-3)
	notify_sampler_coping_completed()
	return false


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
	if v == "panic_shield":
		_handle_panic_shield_var(info)
		return
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


func _handle_panic_shield_var(info: Dictionary) -> void:
	if _shield_clamping:
		return
	var new_f: float = _to_float_safe(info.get("new_value"))
	var target: int = clampi(int(round(new_f)), 0, PANIC_SHIELD_MAX)
	if int(round(new_f)) != target:
		_shield_clamping = true
		Dialogic.VAR.set_variable("panic_shield", target)
		_shield_clamping = false
		target = clampi(int(float(Dialogic.VAR.get_variable("panic_shield", 0))), 0, PANIC_SHIELD_MAX)
	_panic_shield_cache = target


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
	if OS.is_debug_build():
		var nv_str := str(nv)
		if abs(delta_i) > _RELATIONSHIP_TOAST_DELTA_WARN_ABS or nv_str.length() > _RELATIONSHIP_TOAST_VALUE_STR_LEN_WARN:
			push_warning(
				"CelestialVNState: suspicious relationship point change: %s orig=%s new=%s delta=%d"
				% [v, str(info.get("orig_value")), nv_str, delta_i]
			)
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
	if is_blocking_overlay_vn():
		Dialogic.Inputs.action_was_consumed = true
		return
	var vp := get_viewport()
	if vp == null:
		return
	var hovered: Control = vp.gui_get_hovered_control()
	if is_sampler_blocking_vn() and hovered and _control_is_under_sampler(hovered):
		Dialogic.Inputs.action_was_consumed = true
		return
	if not is_crisis_advance_blocked():
		return
	# Do not soft-lock the story before Breath Tempering exists in the Sampler Box.
	if not _breath_tempering_unlocked_in_variables():
		return
	if hovered and _control_is_under_sampler(hovered):
		return
	Dialogic.Inputs.action_was_consumed = true


func _breath_tempering_unlocked_in_variables() -> bool:
	var v: Variant = Dialogic.VAR.get_variable("breath_tempering_unlocked", 0)
	return int(float(str(v))) != 0


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


## Debug-only: best-effort hard reset of VN blockers so Dialogic jumping can't leave input consumed.
## Never call in release builds.
func debug_force_neutralize_vn_blockers() -> void:
	if not OS.is_debug_build():
		return

	# Close sampler and stop any embedded minigames.
	if _sampler_layer != null and is_instance_valid(_sampler_layer) and _sampler_layer.has_method("reset_for_menu"):
		_sampler_layer.call("reset_for_menu")
	set_sampler_blocking_vn(false)

	# Restore any hidden Dialogic chrome + HUD from minigame modal focus.
	while _minigame_modal_refcount > 0:
		end_minigame_modal_focus()
	_minigame_modal_saved.clear()

	# Force-clear overlay refcount that blocks Dialogic advance.
	_blocking_overlay_refcount = 0
