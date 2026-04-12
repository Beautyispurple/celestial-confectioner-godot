extends CanvasLayer

@onready var _panel: PanelContainer = $Root/Panel
@onready var _status_label: Label = $Root/Panel/Margin/VBox/StatusLabel
@onready var _jump_dropdown: OptionButton = $Root/Panel/Margin/VBox/JumpTargetDropdown
@onready var _jump_button: Button = $Root/Panel/Margin/VBox/JumpButton
@onready var _unlock_dropdown: OptionButton = $Root/Panel/Margin/VBox/UnlockPathDropdown
@onready var _apply_jump_button: Button = $Root/Panel/Margin/VBox/ApplyUnlockAndJumpButton
@onready var _suppress_tutorials: CheckBox = $Root/Panel/Margin/VBox/SuppressTutorials

var _jump_in_progress: bool = false

## Project default `visualnovelwithportrait.tres` uses speaker-portrait textbox only (group dialogic_portrait_con_speaker).
## Timelines that use `join ... left/right` need VN portrait layers (dialogic_portrait_con_position) — same as normal play (e.g. marzi_visual_novel_style).
const DEBUG_JUMP_STYLE_WITH_POSITION_CONTAINERS := "marzi_visual_novel_style"


const MAJOR_JUMP_POINTS: Array[Dictionary] = [
	{"name": "Intro: Prologue start (Attic)", "timeline": "intro_sequence", "label": "prologue_attic"},
	{"name": "Intro: Arrive at Gilded Macaron", "timeline": "intro_sequence", "label": "prologue_gm"},
	{"name": "Intro: Return home (Kitchen dinner)", "timeline": "intro_sequence", "label": "prologue_kitchen"},
	{"name": "Intro: Panic choice hub", "timeline": "intro_sequence", "label": "prologue_panic_choice"},
	{"name": "Intro: Panic choice – parents", "timeline": "intro_sequence", "label": "prologue_panic_choice_parents"},
	{"name": "Intro: Panic choice – water (Cold Sheen unlock)", "timeline": "intro_sequence", "label": "prologue_panic_choice_water"},
	{"name": "Intro: Panic choice – meditation (Breath Aeration unlock)", "timeline": "intro_sequence", "label": "prologue_panic_choice_meditation"},
	{"name": "Intro: Panic choice – five senses (Sensory Sifting unlock)", "timeline": "intro_sequence", "label": "prologue_panic_choice_5things"},
	{"name": "Intro: Panic choice – tough it out", "timeline": "intro_sequence", "label": "prologue_panic_choice_tough"},
	{"name": "Intro: Panic choice – bank app (crisis heat)", "timeline": "intro_sequence", "label": "prologue_panic_choice_bank"},
	{"name": "Day 0: Morning start", "timeline": "day_0", "label": "morning_day_0"},
	{"name": "Day 0: Huck intro (break lounge)", "timeline": "day_0", "label": "huck_intro"},
	{"name": "Day 0: Negative thought flow start", "timeline": "day_0", "label": "negative_thought"},
	{"name": "Day 0: Negative thought gate (dragee unlock call)", "timeline": "day_0", "label": "negative_thought_feeling_check"},
	{"name": "Day 0: Negative thought completed", "timeline": "day_0", "label": "negative_thought_completed"},
	{"name": "Day 0: Apartment visit", "timeline": "day_0", "label": "apartment_visit"},
	{"name": "Day 0: Packing attic", "timeline": "day_0", "label": "packing_attic"},
]


const UNLOCK_PATHS: Array[Dictionary] = [
	{
		"name": "Unlock: Breath Tempering (flag only)",
		"timeline": "intro_sequence",
		"label": "prologue_gm",
		"vars": {"breath_tempering_unlocked": 1},
	},
	{
		"name": "Unlock: Cold Sheen (water path)",
		"timeline": "intro_sequence",
		"label": "prologue_panic_choice_water",
		"vars": {"cold_sheen_unlocked": 1},
	},
	{
		"name": "Unlock: Breath Aeration (meditation path)",
		"timeline": "intro_sequence",
		"label": "prologue_panic_choice_meditation",
		"vars": {"breath_aeration_unlocked": 1, "panic_points": 0, "tired": 0},
	},
	{
		"name": "Unlock: Sensory Sifting (five-senses intro path)",
		"timeline": "intro_sequence",
		"label": "prologue_panic_choice_5things",
		"vars": {"sensory_sifting_unlocked": 1},
	},
	{
		"name": "Unlock: Dragee Decisions (jump to Huck gate; call still runs in timeline)",
		"timeline": "day_0",
		"label": "negative_thought_feeling_check",
		"vars": {"willing": 1},
	},
]


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	visible = false
	_panel.visible = true

	_jump_dropdown.clear()
	for i in range(MAJOR_JUMP_POINTS.size()):
		_jump_dropdown.add_item(str(MAJOR_JUMP_POINTS[i].get("name", "Jump %d" % i)), i)

	_unlock_dropdown.clear()
	for i in range(UNLOCK_PATHS.size()):
		_unlock_dropdown.add_item(str(UNLOCK_PATHS[i].get("name", "Unlock %d" % i)), i)

	_jump_button.pressed.connect(_on_jump_pressed)
	_apply_jump_button.pressed.connect(_on_apply_and_jump_pressed)

	set_process(true)


func toggle_visible() -> void:
	if not OS.is_debug_build():
		return
	visible = not visible


func is_jump_in_progress() -> bool:
	return _jump_in_progress


func _process(_delta: float) -> void:
	if not visible:
		return
	_status_label.text = "Dialogic: %s | blocked=%s | sampler_block=%s" % [
		_dialogic_state_string(),
		str(CelestialVNState.is_blocking_overlay_vn()),
		str(CelestialVNState.is_sampler_blocking_vn()),
	]


func _dialogic_state_string() -> String:
	if not is_instance_valid(Dialogic):
		return "missing"
	var st: int = int(Dialogic.current_state)
	match st:
		Dialogic.States.IDLE:
			return "IDLE"
		Dialogic.States.REVEALING_TEXT:
			return "REVEALING_TEXT"
		Dialogic.States.AWAITING_CHOICE:
			return "AWAITING_CHOICE"
		Dialogic.States.ANIMATING:
			return "ANIMATING"
		Dialogic.States.WAITING:
			return "WAITING"
		_:
			return str(st)


func _on_jump_pressed() -> void:
	var idx: int = _jump_dropdown.get_selected_id()
	var target: Dictionary = MAJOR_JUMP_POINTS[idx] if idx >= 0 and idx < MAJOR_JUMP_POINTS.size() else {}
	await _debug_safe_jump(str(target.get("timeline", "")), str(target.get("label", "")), {}, false)


func _on_apply_and_jump_pressed() -> void:
	var idx: int = _unlock_dropdown.get_selected_id()
	var path: Dictionary = UNLOCK_PATHS[idx] if idx >= 0 and idx < UNLOCK_PATHS.size() else {}
	var vars: Dictionary = path.get("vars", {}) as Dictionary
	await _debug_safe_jump(
		str(path.get("timeline", "")),
		str(path.get("label", "")),
		vars,
		_suppress_tutorials.button_pressed
	)


## Wait until Dialogic layout is parented, ready, and has portrait + background nodes (load_style uses deferred add_child).
func _await_dialogic_layout_visual_ready() -> bool:
	const MAX_FRAMES := 120
	var last_fail := ""
	for _i in MAX_FRAMES:
		last_fail = _dialogic_layout_visual_ready_fail_reason()
		if last_fail.is_empty():
			return true
		await get_tree().process_frame
	push_error("[DebugJump] Layout visual ready timeout (%d frames): %s" % [MAX_FRAMES, last_fail])
	return false


func _dialogic_layout_visual_ready_fail_reason() -> String:
	if not is_instance_valid(Dialogic) or not Dialogic.has_subsystem("Styles"):
		return "no Dialogic Styles"
	if not Dialogic.Styles.has_active_layout_node():
		return "no active layout"
	var layout: Node = Dialogic.Styles.get_layout_node()
	if not is_instance_valid(layout):
		return "layout null"
	if not layout.is_inside_tree():
		return "layout not in tree"
	if not layout.is_node_ready():
		return "layout not ready"
	if Dialogic.Styles.get_first_node_in_layout("dialogic_background_holders") == null:
		return "no dialogic_background_holders under layout"
	var portrait_ok := Dialogic.Styles.get_first_node_in_layout("dialogic_portrait_con_position") != null
	if not portrait_ok:
		for n in get_tree().get_nodes_in_group(&"dialogic_portrait_con_position"):
			if layout.is_ancestor_of(n):
				portrait_ok = true
				break
	if not portrait_ok:
		return "no dialogic_portrait_con_position under layout"
	return ""


func _resolve_debug_jump_layout_style(preserved_base: String) -> String:
	var candidate := preserved_base.strip_edges()
	if candidate.is_empty():
		candidate = str(ProjectSettings.get_setting("dialogic/layout/default_style", ""))
	if candidate.is_empty():
		return DEBUG_JUMP_STYLE_WITH_POSITION_CONTAINERS
	var norm := candidate.to_lower().replace("\\", "/")
	if norm == "visualnovelwithportrait":
		return DEBUG_JUMP_STYLE_WITH_POSITION_CONTAINERS
	if norm.ends_with("visualnovelwithportrait.tres"):
		return DEBUG_JUMP_STYLE_WITH_POSITION_CONTAINERS
	if norm.get_file().get_basename() == "visualnovelwithportrait":
		return DEBUG_JUMP_STYLE_WITH_POSITION_CONTAINERS
	return candidate


func _debug_safe_jump(timeline: String, label: String = "", pre_vars: Dictionary = {}, suppress_tutorials: bool = false) -> void:
	if not OS.is_debug_build():
		return
	if _jump_in_progress:
		return
	if timeline.strip_edges().is_empty():
		return

	_jump_in_progress = true
	await _run_debug_safe_jump(timeline, label, pre_vars, suppress_tutorials)
	_jump_in_progress = false


func _run_debug_safe_jump(timeline: String, label: String, pre_vars: Dictionary, suppress_tutorials: bool) -> void:
	CelestialVNState.debug_force_neutralize_vn_blockers()

	var preserved_base_style := ""
	if is_instance_valid(Dialogic):
		preserved_base_style = str(Dialogic.current_state_info.get("base_style", ""))

	if is_instance_valid(Dialogic):
		await Dialogic.end_timeline(true)
		# end_timeline(skip_ending=true) only clears timeline info; portrait subsystem state can still
		# reference nodes from the old layout (now freed), causing "previously freed" errors on restart.
		if Dialogic.has_subsystem("Portraits"):
			Dialogic.Portraits.clear_game_state(Dialogic.ClearFlags.FULL_CLEAR)
		Dialogic.current_state_info["portraits"] = {}
		Dialogic.current_state_info["speaker"] = ""

	CelestialVNState.resync_dialogic_variables_from_project_defaults()

	for k in pre_vars.keys():
		Dialogic.VAR.set_variable(str(k), pre_vars[k])

	if suppress_tutorials:
		Dialogic.VAR.set_variable("sampler_tutorial_chain_done", 1)
		Dialogic.VAR.set_variable("dragee_disposal_tutorial_done", 1)

	# Load a style that includes VN portrait position containers (join left/right). Deferred add_child — wait after.
	if is_instance_valid(Dialogic) and Dialogic.has_subsystem("Styles"):
		var style_to_load: String = _resolve_debug_jump_layout_style(preserved_base_style)
		Dialogic.Styles.load_style(style_to_load, null, true, false)

	if not await _await_dialogic_layout_visual_ready():
		return

	if label.strip_edges().is_empty():
		Dialogic.start(timeline)
	else:
		Dialogic.start(timeline, label)

	if is_instance_valid(Dialogic):
		await Dialogic.timeline_started
