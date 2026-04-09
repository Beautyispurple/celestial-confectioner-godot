extends Node
## Negative-thought dragee flow: shelf (6), action log (20), disposal mini, sampler/story entry.

const RESULT_CANCEL := 0
const RESULT_DISPOSED := 1
const RESULT_SHELVED := 2
const RESULT_SHELF_FULL := 3

const SHELF_MAX := 6
const LOG_MAX := 20
const SEQ_SCENE := preload("res://ui/dragee_disposal_sequence.tscn")
const MODAL_SCENE := preload("res://ui/dragee_disposal_modal.tscn")

signal shelf_changed
signal action_log_changed

## Mirrors Dialogic `dragee_disposal_unlocked`: Dialogic set_variable fails if the key is missing from loaded saves.
var _sampler_unlocked: bool = false

var shelf: Array = []
var action_log: Array = []
var social_buff_charges: int = 0


func is_dragee_sampler_unlocked() -> bool:
	if _sampler_unlocked:
		return true
	if Dialogic.VAR.has("dragee_disposal_unlocked"):
		return int(float(str(Dialogic.VAR.get_variable("dragee_disposal_unlocked", 0)))) != 0
	return false


func sync_unlock_flag_from_dialogic() -> void:
	if Dialogic.VAR.has("dragee_disposal_unlocked"):
		if int(float(str(Dialogic.VAR.get_variable("dragee_disposal_unlocked", 0)))) != 0:
			_sampler_unlocked = true


## After load + resync: grant sampler slot if the story already awarded the Huck beat bonus once.
func apply_save_migration_for_sampler_unlock() -> void:
	if is_dragee_sampler_unlocked():
		return
	if not Dialogic.VAR.has("dragee_huck_story_bonus_done"):
		return
	if int(float(str(Dialogic.VAR.get_variable("dragee_huck_story_bonus_done", 0)))) == 0:
		return
	unlock_from_story()


func reset_new_game() -> void:
	shelf.clear()
	action_log.clear()
	social_buff_charges = 0
	_sampler_unlocked = false
	shelf_changed.emit()
	action_log_changed.emit()


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var s: Variant = data.get("shelf", [])
	shelf = s as Array if s is Array else []
	var l: Variant = data.get("action_log", [])
	action_log = l as Array if l is Array else []
	social_buff_charges = clampi(int(data.get("social_buff_charges", 0)), 0, 99)
	_sampler_unlocked = bool(data.get("sampler_unlocked", false))
	shelf_changed.emit()
	action_log_changed.emit()


func get_save_data() -> Dictionary:
	return {
		"shelf": shelf.duplicate(true),
		"action_log": action_log.duplicate(true),
		"social_buff_charges": social_buff_charges,
		"sampler_unlocked": _sampler_unlocked,
	}


func consume_social_buff_if_any(raw_loss: int) -> int:
	if raw_loss <= 0 or social_buff_charges <= 0:
		return raw_loss
	social_buff_charges -= 1
	return int(ceil(float(raw_loss) * 0.5))


func shelf_entry_count() -> int:
	return mini(shelf.size(), SHELF_MAX)


func get_shelf_entry_at(slot: int) -> Variant:
	if slot < 0 or slot >= shelf.size():
		return null
	return shelf[slot]


func try_add_shelf_entry(thought_text: String, source: String, helpful: bool) -> bool:
	if shelf.size() >= SHELF_MAX:
		return false
	var entry := {
		"thought_text": str(thought_text).strip_edges(),
		"created_at": Time.get_datetime_string_from_system(),
		"source": source,
		"helpful": helpful,
	}
	shelf.append(entry)
	shelf_changed.emit()
	ResearchTelemetry.record_event("dragee_verbatim", {"kind": "shelf", "text": str(thought_text).strip_edges()})
	return true


func remove_shelf_at(index: int) -> void:
	if index < 0 or index >= shelf.size():
		return
	shelf.remove_at(index)
	shelf_changed.emit()


func append_action_log(action_text: String, thought_snip: String) -> void:
	var line := str(action_text).strip_edges()
	if line.is_empty():
		return
	var entry := {
		"text": line,
		"created_at": Time.get_datetime_string_from_system(),
		"done": false,
		"thought_snip": thought_snip.strip_edges(),
	}
	action_log.insert(0, entry)
	while action_log.size() > LOG_MAX:
		action_log.remove_at(action_log.size() - 1)
	action_log_changed.emit()


func set_action_log_done(index: int, done: bool) -> void:
	if index < 0 or index >= action_log.size():
		return
	var e: Variant = action_log[index]
	if e is Dictionary:
		(e as Dictionary)["done"] = done
		action_log_changed.emit()


func unlock_from_story() -> void:
	_sampler_unlocked = true
	CelestialVNState.resync_dialogic_variables_from_project_defaults()
	Dialogic.VAR.set_variable("dragee_disposal_unlocked", 1)
	CelestialVNState.refresh_sampler_slots()


## Call from timeline at `negative_thought_feeling_check`: enables Sampler replay + one-time skill tutorial.
func after_negative_thought_gate() -> void:
	unlock_from_story()
	if int(float(str(Dialogic.VAR.get_variable("dragee_disposal_tutorial_done", 0)))) != 0:
		return
	await CelestialTutorial.prologue_tutorial_dragee_disposal_unlocked()
	Dialogic.VAR.set_variable("dragee_disposal_tutorial_done", 1)


func _set_flow_result(code: int) -> void:
	Dialogic.VAR.set_variable("dragee_flow_result_code", code)
	ResearchTelemetry.record_event("dragee_outcome", {"code": code})


func _sync_thought(t: String) -> void:
	Dialogic.VAR.set_variable("negative_thought_game.thought_1", t)


func _sync_action(a: String) -> void:
	Dialogic.VAR.set_variable("negative_thought_game.action_1", a)


func _apply_disposal_rewards(action_line: String, thought_snip: String, from_story: bool) -> void:
	CelestialVNState.apply_direct_panic_delta(-3)
	if CelestialVNState.get_panic_tier() == CelestialVNState.PanicTier.CRISIS:
		CelestialVNState.notify_sampler_coping_completed()
	social_buff_charges = mini(social_buff_charges + 3, 99)
	append_action_log(action_line, thought_snip)
	if from_story:
		Dialogic.VAR.set_variable("dragee_huck_scene_disposed", 1)
	else:
		Dialogic.VAR.set_variable("dragee_sampler_dispose_count", int(float(str(Dialogic.VAR.get_variable("dragee_sampler_dispose_count", 0)))) + 1)


func _prompt_line(title: String, placeholder: String = "", initial: String = "") -> Dictionary:
	var m: Node = MODAL_SCENE.instantiate()
	get_tree().root.add_child(m)
	await get_tree().process_frame
	var st := {"done": false, "cancelled": true, "out": ""}
	if m.has_signal("settled"):
		m.settled.connect(
			func(t: String, can: bool) -> void:
				st["out"] = t
				st["cancelled"] = can
				st["done"] = true
		)
	if m.has_method("present"):
		m.call("present", title, placeholder, initial)
	while not st["done"]:
		await get_tree().process_frame
	m.queue_free()
	var ok_line := not bool(st["cancelled"])
	var out_txt := str(st["out"]).strip_edges()
	if ok_line and not out_txt.is_empty():
		ResearchTelemetry.record_event("dragee_verbatim", {"prompt": title, "text": out_txt})
	return {"ok": ok_line, "text": str(st["out"])}


func _prompt_confirm(title: String) -> Dictionary:
	var m: Node = MODAL_SCENE.instantiate()
	get_tree().root.add_child(m)
	await get_tree().process_frame
	var st := {"done": false, "cancelled": true}
	if m.has_signal("settled"):
		m.settled.connect(
			func(_t: String, can: bool) -> void:
				st["cancelled"] = can
				st["done"] = true
		)
	if m.has_method("present_confirm"):
		m.call("present_confirm", title)
	while not st["done"]:
		await get_tree().process_frame
	m.queue_free()
	return {"ok": not bool(st["cancelled"])}


func _prompt_helpful() -> Variant:
	var m: Node = MODAL_SCENE.instantiate()
	get_tree().root.add_child(m)
	await get_tree().process_frame
	var st := {"done": false, "helpful": false, "aborted": false}
	if m.has_signal("helpful_chosen"):
		m.helpful_chosen.connect(
			func(h: bool) -> void:
				st["helpful"] = h
				st["done"] = true
		)
	if m.has_signal("helpful_cancelled"):
		m.helpful_cancelled.connect(
			func() -> void:
				st["aborted"] = true
				st["done"] = true
		)
	if m.has_method("present_helpful_choice"):
		m.call("present_helpful_choice", "Does holding on to this thought help you live by what you value?")
	while not st["done"]:
		await get_tree().process_frame
	m.queue_free()
	if bool(st["aborted"]):
		return null
	return st["helpful"]


func _run_dispose_sequence(thought_display: String) -> bool:
	var seq: Node = SEQ_SCENE.instantiate()
	get_tree().root.add_child(seq)
	await get_tree().process_frame
	var ok: bool = await seq.run_sequence(thought_display)
	seq.queue_free()
	return ok


func run_story_not_helpful() -> void:
	CelestialVNState.begin_blocking_overlay_vn()
	CelestialVNState.begin_minigame_modal_focus()
	var thought: String = str(Dialogic.VAR.get_variable("negative_thought_game.thought_1", ""))
	var pr: Dictionary = await _prompt_line(
		"What can you do about this thought?",
		"I can…",
		""
	)
	if not pr["ok"]:
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	var action_line: String = str(pr["text"])
	if action_line.is_empty():
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_sync_action(action_line)
	if not await _run_dispose_sequence(thought):
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_apply_disposal_rewards(action_line, thought, true)
	_set_flow_result(RESULT_DISPOSED)
	CelestialVNState.end_minigame_modal_focus()
	CelestialVNState.end_blocking_overlay_vn()


func run_story_helpful() -> void:
	CelestialVNState.begin_blocking_overlay_vn()
	CelestialVNState.begin_minigame_modal_focus()
	var thought: String = str(Dialogic.VAR.get_variable("negative_thought_game.thought_1", ""))
	var pr: Dictionary = await _prompt_line(
		"What can you do about this thought while you keep it?",
		"I can…",
		""
	)
	if not pr["ok"]:
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	var action_line: String = str(pr["text"])
	if action_line.is_empty():
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_sync_action(action_line)
	if not try_add_shelf_entry(thought, "huck_scene", true):
		await _prompt_confirm("Your thought shelf is full (6). Let something go from the Sampler → Life tools before adding another.")
		_set_flow_result(RESULT_SHELF_FULL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_set_flow_result(RESULT_SHELVED)
	CelestialVNState.end_minigame_modal_focus()
	CelestialVNState.end_blocking_overlay_vn()


func run_fresh_from_sampler() -> void:
	CelestialVNState.begin_blocking_overlay_vn()
	CelestialVNState.begin_minigame_modal_focus()
	var t1: Dictionary = await _prompt_line("Name one negative thought you are having.", "I'm not good enough.", "")
	if not t1["ok"]:
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	var thought: String = str(t1["text"]).strip_edges()
	if thought.is_empty():
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_sync_thought(thought)
	var hv: Variant = await _prompt_helpful()
	if hv == null:
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	var helpful: bool = hv as bool
	var pr: Dictionary = await _prompt_line(
		"What can you do about this thought?",
		"I can…",
		""
	)
	if not pr["ok"]:
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	var action_line: String = str(pr["text"])
	if action_line.is_empty():
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_sync_action(action_line)
	if helpful:
		if not try_add_shelf_entry(thought, "sampler", true):
			await _prompt_confirm("Your thought shelf is full (6). Dispose a saved thought from Life tools first.")
			_set_flow_result(RESULT_SHELF_FULL)
			CelestialVNState.end_minigame_modal_focus()
			CelestialVNState.end_blocking_overlay_vn()
			return
		_set_flow_result(RESULT_SHELVED)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	if not await _run_dispose_sequence(thought):
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_apply_disposal_rewards(action_line, thought, false)
	_set_flow_result(RESULT_DISPOSED)
	CelestialVNState.end_minigame_modal_focus()
	CelestialVNState.end_blocking_overlay_vn()


func run_from_shelf_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= shelf.size():
		_set_flow_result(RESULT_CANCEL)
		return
	var ent: Variant = shelf[slot_index]
	if ent == null or not ent is Dictionary:
		_set_flow_result(RESULT_CANCEL)
		return
	var thought: String = str((ent as Dictionary).get("thought_text", ""))
	CelestialVNState.begin_blocking_overlay_vn()
	CelestialVNState.begin_minigame_modal_focus()
	var cf: Dictionary = await _prompt_confirm("Still want to let this thought go?")
	if not cf["ok"]:
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_sync_thought(thought)
	var pr: Dictionary = await _prompt_line(
		"What can you do about it right now?",
		"I can…",
		""
	)
	if not pr["ok"]:
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	var action_line: String = str(pr["text"])
	if action_line.is_empty():
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	_sync_action(action_line)
	if not await _run_dispose_sequence(thought):
		_set_flow_result(RESULT_CANCEL)
		CelestialVNState.end_minigame_modal_focus()
		CelestialVNState.end_blocking_overlay_vn()
		return
	remove_shelf_at(slot_index)
	_apply_disposal_rewards(action_line, thought, false)
	_set_flow_result(RESULT_DISPOSED)
	CelestialVNState.end_minigame_modal_focus()
	CelestialVNState.end_blocking_overlay_vn()
