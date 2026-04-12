extends Node
## Research session bundle, resilient telemetry facade, survey/transparency orchestration.
## All record_event calls no-op when not research release or not opted in.

const COULD_NOT_TRACK := "COULD NOT TRACK"

var _inited: bool = false
var _survey_flow_running: bool = false
var _text_input_prompt_cache: String = ""
## Set when research notice is shown; moved into session when player opts in.
var _pending_notice_unix: float = 0.0
var _pre_init_events: Array = []

## In-memory session; keys used by transparency and analysis.
var session: Dictionary = {}

## metric_id -> true when recording failed (transparency shows COULD NOT TRACK).
var _metric_failures: Dictionary = {}


func is_active() -> bool:
	return ReleaseMode.IS_RESEARCH_RELEASE and ResearchConsentState.research_metrics_opt_in


func init_if_allowed() -> void:
	if _inited:
		return
	if not ReleaseMode.IS_RESEARCH_RELEASE:
		return
	if not ResearchConsentState.research_metrics_opt_in:
		return
	_inited = true
	for e in _pre_init_events:
		if e is Dictionary:
			var d: Dictionary = e
			_apply_event(str(d.get("name", "")), d.get("payload"))
	_pre_init_events.clear()
	_connect_signals_safe()
	if OS.is_debug_build():
		print("[ResearchTelemetry] init_if_allowed")


func shutdown() -> void:
	if not _inited:
		return
	_disconnect_signals_safe()
	_inited = false
	session.clear()
	_metric_failures.clear()
	_pre_init_events.clear()
	_pending_notice_unix = 0.0


func record_event(event_name: String, payload: Variant = null) -> void:
	if not ReleaseMode.IS_RESEARCH_RELEASE or not ResearchConsentState.research_metrics_opt_in:
		return
	if not _inited:
		_pre_init_events.append({"name": event_name, "payload": payload})
		return
	_apply_event(str(event_name), payload)


func mark_metric_failed(metric_id: String) -> void:
	_metric_failures[str(metric_id)] = true


func begin_session_from_load() -> void:
	if not is_active():
		return
	session["session_started_via"] = "load"
	session["demo_wall_start_valid"] = false
	session["demo_duration_na"] = true
	session["session_load_at_unix"] = Time.get_unix_time_from_system()


## Call when research notice layer is shown (new game); wall clock starts here if player later opts in.
func mark_research_notice_shown() -> void:
	if not ReleaseMode.IS_RESEARCH_RELEASE:
		return
	_pending_notice_unix = Time.get_unix_time_from_system()


## Call from ResearchConsentState when player accepts research metrics (after checkbox / SAM).
func flush_pending_notice_after_opt_in() -> void:
	if not ResearchConsentState.research_metrics_opt_in:
		return
	if _pending_notice_unix <= 0.0:
		return
	session["research_notice_shown_at_unix"] = _pending_notice_unix
	session["demo_wall_start_unix"] = _pending_notice_unix
	session["demo_wall_start_valid"] = true
	session["session_started_via"] = "new_game"
	session["demo_duration_na"] = false
	_inc_counter("research_notice_shown_count")
	_pending_notice_unix = 0.0


func mark_consent_pack_completed() -> void:
	if not is_active():
		return
	session["consent_completed_at_unix"] = Time.get_unix_time_from_system()


func add_pause_duration_sec(sec: float) -> void:
	if not is_active():
		return
	if sec <= 0.0:
		return
	var p: float = float(session.get("pause_accumulated_sec", 0.0))
	session["pause_accumulated_sec"] = p + sec


## Async: shows survey then transparency; Dialogic awaits this at demo end.
func request_end_of_demo_survey() -> void:
	if not is_active():
		return
	if _survey_flow_running:
		return
	_survey_flow_running = true
	var err_msg: Variant = await _run_survey_then_transparency()
	if err_msg != null and str(err_msg) != "":
		mark_metric_failed("survey_flow")
		if OS.is_debug_build():
			push_warning("[ResearchTelemetry] survey_flow: %s" % str(err_msg))
	_survey_flow_running = false


func submit_survey_answers(data: Dictionary) -> void:
	if not is_active():
		return
	session["survey"] = data.duplicate(true)
	if data.has("post_sam"):
		session["post_sam"] = data["post_sam"]
	session["survey_submitted_at_unix"] = Time.get_unix_time_from_system()
	var shown: float = float(session.get("survey_shown_at_unix", 0.0))
	if shown > 0.0:
		session["survey_duration_sec"] = session["survey_submitted_at_unix"] - shown
	_snapshot_dialogic_milestones()
	_snapshot_journal_verbatim()


func get_demo_session_duration_display() -> Variant:
	if session.get("demo_duration_na", false):
		return null
	if _metric_failures.get("demo_session_duration", false):
		return null
	var start: float = float(session.get("demo_wall_start_unix", 0.0))
	var survey_shown: float = float(session.get("survey_shown_at_unix", 0.0))
	if start <= 0.0 or survey_shown <= 0.0:
		return null
	return survey_shown - start


func get_active_demo_duration_display() -> Variant:
	if session.get("demo_duration_na", false):
		return null
	if _metric_failures.get("active_demo_duration", false):
		return null
	var wall: Variant = get_demo_session_duration_display()
	if wall == null:
		return null
	var pause_sec: float = float(session.get("pause_accumulated_sec", 0.0))
	return maxf(0.0, float(wall) - pause_sec)


func get_session_copy_for_transparency() -> Dictionary:
	var out := session.duplicate(true)
	out["_failures"] = _metric_failures.duplicate()
	return out


func go_to_main_menu_after_dialogic_cleanup() -> void:
	await Dialogic.end_timeline(true)
	if Dialogic.Styles.has_active_layout_node():
		var layout: Node = Dialogic.Styles.get_layout_node()
		if is_instance_valid(layout) and layout.is_inside_tree():
			layout.get_parent().remove_child(layout)
			layout.queue_free()
		if get_tree().has_meta("dialogic_layout_node"):
			get_tree().remove_meta("dialogic_layout_node")
	GameSaveManager.pending_load_slot = -1
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _connect_signals_safe() -> void:
	if not CelestialVNState.panic_tier_changed.is_connected(_on_panic_tier_changed):
		CelestialVNState.panic_tier_changed.connect(_on_panic_tier_changed)
	if not CelestialVNState.crisis_coping_resolved.is_connected(_on_crisis_resolved):
		CelestialVNState.crisis_coping_resolved.connect(_on_crisis_resolved)
	if is_instance_valid(Dialogic):
		if not Dialogic.Choices.choice_selected.is_connected(_on_dialogic_choice_selected):
			Dialogic.Choices.choice_selected.connect(_on_dialogic_choice_selected)
	if Dialogic.TextInput.input_shown.is_connected(_on_text_input_shown):
		pass
	else:
		Dialogic.TextInput.input_shown.connect(_on_text_input_shown)
	if Dialogic.TextInput.input_confirmed.is_connected(_on_text_input_confirmed):
		pass
	else:
		Dialogic.TextInput.input_confirmed.connect(_on_text_input_confirmed)


func _disconnect_signals_safe() -> void:
	if CelestialVNState.panic_tier_changed.is_connected(_on_panic_tier_changed):
		CelestialVNState.panic_tier_changed.disconnect(_on_panic_tier_changed)
	if CelestialVNState.crisis_coping_resolved.is_connected(_on_crisis_resolved):
		CelestialVNState.crisis_coping_resolved.disconnect(_on_crisis_resolved)
	if is_instance_valid(Dialogic):
		if Dialogic.Choices.choice_selected.is_connected(_on_dialogic_choice_selected):
			Dialogic.Choices.choice_selected.disconnect(_on_dialogic_choice_selected)
	if Dialogic.TextInput.input_shown.is_connected(_on_text_input_shown):
		Dialogic.TextInput.input_shown.disconnect(_on_text_input_shown)
	if Dialogic.TextInput.input_confirmed.is_connected(_on_text_input_confirmed):
		Dialogic.TextInput.input_confirmed.disconnect(_on_text_input_confirmed)


func _on_panic_tier_changed(tier: int) -> void:
	record_event("panic_tier", {"tier": tier})


func _on_crisis_resolved() -> void:
	_inc_counter("crisis_coping_resolved_count")


func _on_text_input_shown(info: Dictionary) -> void:
	_text_input_prompt_cache = str(info.get("text", ""))


func _on_text_input_confirmed(input: String) -> void:
	record_event("dialogic_text_input", {"prompt": _text_input_prompt_cache, "text": input})


func _on_dialogic_choice_selected(info: Dictionary) -> void:
	if not is_active():
		return
	var text: String = str(info.get("text", "")).strip_edges()
	if text.is_empty():
		return
	record_event(
		"player_choice",
		{
			"choice_text": text,
			"event_index": info.get("event_index", -1),
			"t_unix": Time.get_unix_time_from_system(),
		}
	)


func _session_append_array(key: String, item: Variant) -> void:
	var v: Variant = session.get(key, null)
	var arr: Array
	if v is Array:
		arr = v
	else:
		arr = []
		session[key] = arr
	arr.append(item)


func _apply_event(event_name: String, payload: Variant) -> void:
	match event_name:
		"dialogic_text_input":
			if payload is Dictionary:
				_session_append_array("dialogic_text_inputs", (payload as Dictionary).duplicate())
		"sampler_open", "sampler_close":
			_inc_counter(event_name)
			if payload is Dictionary:
				session["sampler_last_open"] = bool((payload as Dictionary).get("open", false))
		"sampler_tab":
			if payload is Dictionary:
				var tab: String = str((payload as Dictionary).get("tab", ""))
				_inc_counter("sampler_tab_%s" % tab)
		"minigame_start", "minigame_complete", "minigame_abort":
			if payload is Dictionary:
				var tool: String = str((payload as Dictionary).get("tool", "unknown"))
				_inc_counter("%s_%s" % [event_name, tool])
		"breathing_session_start":
			_inc_counter("breathing_sessions")
			if payload is Dictionary:
				session["breathing_last_mode"] = (payload as Dictionary).get("mode", "")
		"breathing_session_end":
			if payload is Dictionary:
				var d: Dictionary = payload as Dictionary
				_add_float_metric("breathing_total_sec", float(d.get("duration_sec", 0.0)))
				if bool(d.get("completed", false)):
					_inc_counter("breathing_completions")
				if bool(d.get("skipped", false)):
					_inc_counter("breathing_skips")
				_add_float_metric("breathing_cycles_total", float(d.get("cycles", 0.0)))
		"inventory_use":
			if payload is Dictionary:
				var item: String = str((payload as Dictionary).get("item", ""))
				_inc_counter("inv_%s" % item)
		"dragee_outcome":
			if payload is Dictionary:
				_session_append_array("dragee_outcomes", (payload as Dictionary).duplicate())
		"dragee_verbatim":
			if payload is Dictionary:
				_session_append_array("dragee_verbatim", (payload as Dictionary).duplicate())
		"journal_snapshot":
			if payload is Dictionary:
				session["journal_last_snapshot"] = (payload as Dictionary).duplicate(true)
				_session_append_array("journal_snapshots", (payload as Dictionary).duplicate(true))
		"pause_open":
			session["pause_last_open_unix"] = Time.get_unix_time_from_system()
		"pause_close":
			var open_u: float = float(session.get("pause_last_open_unix", 0.0))
			if open_u > 0.0:
				add_pause_duration_sec(Time.get_unix_time_from_system() - open_u)
				session["pause_last_open_unix"] = 0.0
			_inc_counter("pause_close_count")
		"safety_open":
			_inc_counter("safety_open_count")
		"save_game":
			_inc_counter("save_count")
		"load_game":
			_inc_counter("load_count")
		"pre_sam":
			if payload is Dictionary:
				session["pre_sam"] = (payload as Dictionary).duplicate(true)
		"post_sam":
			if payload is Dictionary:
				session["post_sam"] = (payload as Dictionary).duplicate(true)
		"player_choice":
			if payload is Dictionary:
				_session_append_array("player_choice_log", (payload as Dictionary).duplicate(true))
		_:
			_session_append_array(
				"misc_events",
				{"name": event_name, "payload": payload, "t": Time.get_unix_time_from_system()}
			)


func _inc_counter(key: String, amount: int = 1) -> void:
	var n: int = int(session.get(key, 0))
	session[key] = n + amount


func _add_float_metric(key: String, delta: float) -> void:
	if delta == 0.0:
		return
	var f: float = float(session.get(key, 0.0))
	session[key] = f + delta


func _snapshot_dialogic_milestones() -> void:
	var keys := [
		"panic_points", "social_battery", "panic_shield", "sensory_sifting_unlocked",
		"breath_tempering_unlocked", "breath_aeration_unlocked", "cold_sheen_unlocked",
		"dragee_disposal_unlocked", "journal_unlocked", "gold_coin", "tired"
	]
	var snap := {}
	for k in keys:
		if Dialogic.VAR.has(k):
			snap[k] = Dialogic.VAR.get_variable(k)
	session["dialogic_milestones"] = snap


func _snapshot_journal_verbatim() -> void:
	var draft := CelestialJournal.get_draft()
	var fin: Array = []
	var c: int = CelestialJournal.get_finished_count()
	var max_n: int = mini(c, 32)
	for i in max_n:
		fin.append(CelestialJournal.get_finished_entry(i))
	session["journal_survey_snapshot"] = {"draft": draft, "finished_sample": fin}


func _run_survey_then_transparency() -> Variant:
	var root := get_tree().root
	var packed: PackedScene = load("res://ui/research_survey_layer.tscn") as PackedScene
	if packed == null:
		return "missing survey scene"
	session["survey_shown_at_unix"] = Time.get_unix_time_from_system()
	var layer: CanvasLayer = packed.instantiate() as CanvasLayer
	layer.layer = 200
	root.add_child(layer)
	if layer.has_method(&"run_survey"):
		await layer.call(&"run_survey")
	else:
		layer.queue_free()
		return "survey missing run_survey"
	if is_instance_valid(layer):
		layer.queue_free()
	await get_tree().process_frame
	var packed_t: PackedScene = load("res://ui/research_transparency_layer.tscn") as PackedScene
	if packed_t == null:
		return "missing transparency scene"
	var trans: CanvasLayer = packed_t.instantiate() as CanvasLayer
	trans.layer = 201
	root.add_child(trans)
	if trans.has_method(&"run_until_done"):
		await trans.call(&"run_until_done")
	else:
		trans.queue_free()
		return "transparency missing run_until_done"
	if is_instance_valid(trans):
		trans.queue_free()
	await go_to_main_menu_after_dialogic_cleanup()
	return null
