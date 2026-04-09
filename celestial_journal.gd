extends Node
## Autoload: journal draft, finished history (capped), daily coin tracking for Dialogic gold_coin.
##
## GATING (production): Dialogic variable `journal_unlocked` defaults to 1 in development
## (see project.godot dialogic variables). Set default to 0 for production until story unlock
## (e.g. "met a character") is implemented.

const JOURNAL_SAVE_VERSION := 1
const MAX_FINISHED_ENTRIES := 512
const DAILY_COIN_AMOUNTS := [500, 250, 100]

signal draft_changed
signal history_changed
signal view_changed

var _finished: Array = []
## Calendar day key YYYY-MM-DD (local) for daily coin cap
var _coin_day_key: String = ""
var _finishes_on_coin_day: int = 0
var _draft: Dictionary = {}
var _view_index: int = 0
## -1 while overlay closed; set when opening
var _session_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	JournalPrompts.ensure_loaded()
	_reset_draft_if_empty()


func is_journal_session_active() -> bool:
	return _session_active


func set_journal_session_active(v: bool) -> void:
	_session_active = v


func get_view_index() -> int:
	return _view_index


func set_view_index(i: int) -> void:
	var mx: int = _finished.size()
	_view_index = clampi(i, 0, mx)
	view_changed.emit()


## Index of "new draft" slot (one past last finished)
func get_new_draft_index() -> int:
	return _finished.size()


func get_finished_count() -> int:
	return _finished.size()


func get_finished_entry(i: int) -> Dictionary:
	if i < 0 or i >= _finished.size():
		return {}
	return _finished[i].duplicate(true)


func get_draft() -> Dictionary:
	return _draft.duplicate(true)


## History entries are read-only; index == finished.size() is the editable draft.
func get_current_entry_for_display() -> Dictionary:
	if _view_index < _finished.size():
		return _finished[_view_index].duplicate(true)
	return _draft.duplicate(true)


func is_viewing_history_readonly() -> bool:
	return _view_index < _finished.size()


func update_draft_from_ui(d: Dictionary) -> void:
	if is_viewing_history_readonly():
		return
	_draft = d.duplicate(true)
	draft_changed.emit()


func set_draft(d: Dictionary) -> void:
	if is_viewing_history_readonly():
		return
	_draft = d.duplicate(true)
	draft_changed.emit()


func _reset_draft_if_empty() -> void:
	if _draft.is_empty():
		_draft = _make_blank_draft()


func _make_blank_draft() -> Dictionary:
	var cat: String = JournalPrompts.get_categories()[0] if JournalPrompts.get_categories().size() > 0 else "Balance Bars"
	var p: Dictionary = JournalPrompts.random_prompt(cat)
	return {
		"version": JOURNAL_SAVE_VERSION,
		"category": p.get("category", cat),
		"prompt_index": int(p.get("index", 0)),
		"prompt_text": str(p.get("text", "")),
		"started_at_unix": int(Time.get_unix_time_from_system()),
		"left": _blank_page(),
		"right": _blank_page(),
	}


func _blank_page() -> Dictionary:
	return {"pencil_png_b64": "", "text_items": [], "stickers": []}


func new_draft_at_end() -> void:
	_view_index = _finished.size()
	_draft = _make_blank_draft()
	view_changed.emit()
	draft_changed.emit()


func load_draft_from_dict(d: Dictionary) -> void:
	if d.is_empty():
		new_draft_at_end()
		return
	_draft = d.duplicate(true)
	if not _draft.has("left"):
		_draft["left"] = _blank_page()
	if not _draft.has("right"):
		_draft["right"] = _blank_page()
	draft_changed.emit()


func apply_category_and_random_prompt(category: String) -> void:
	if is_viewing_history_readonly():
		return
	var p: Dictionary = JournalPrompts.random_prompt(category)
	_draft["category"] = category
	_draft["prompt_index"] = int(p.get("index", 0))
	_draft["prompt_text"] = str(p.get("text", ""))
	draft_changed.emit()


func reroll_prompt() -> void:
	if is_viewing_history_readonly():
		return
	var cat: String = str(_draft.get("category", "Balance Bars"))
	var p: Dictionary = JournalPrompts.random_prompt(cat)
	_draft["prompt_index"] = int(p.get("index", 0))
	_draft["prompt_text"] = str(p.get("text", ""))
	draft_changed.emit()


func prompt_for_current_category_index() -> Dictionary:
	var cat: String = str(_draft.get("category", ""))
	var idx: int = int(_draft.get("prompt_index", 0))
	return JournalPrompts.prompt_by_indices(cat, idx)


## Valid finish: at least one letter of text, OR any stroke, OR one sticker (both pages).
func draft_passes_finish_validation() -> bool:
	if _draft.is_empty():
		return false
	for side in ["left", "right"]:
		var pg: Dictionary = _draft.get(side, {}) as Dictionary
		if _page_has_letter_text(pg):
			return true
		if _page_has_stroke(pg):
			return true
		if _page_has_sticker(pg):
			return true
	return false


func _page_has_letter_text(pg: Dictionary) -> bool:
	var items: Array = pg.get("text_items", []) as Array
	for it in items:
		if it is Dictionary:
			var s: String = str((it as Dictionary).get("text", ""))
			for i in s.length():
				var c: String = s[i]
				var u: int = c.unicode_at(0)
				if (u >= 65 and u <= 90) or (u >= 97 and u <= 122):
					return true
	return false


func _page_has_stroke(pg: Dictionary) -> bool:
	var b64: String = str(pg.get("pencil_png_b64", ""))
	if not b64.is_empty():
		return true
	var strokes: Array = pg.get("strokes", []) as Array
	return strokes.size() > 0


func _page_has_sticker(pg: Dictionary) -> bool:
	var st: Array = pg.get("stickers", []) as Array
	return st.size() > 0


func finish_current_draft() -> int:
	## Returns coins awarded this finish (0–500).
	if is_viewing_history_readonly():
		return 0
	if not draft_passes_finish_validation():
		return 0
	var entry: Dictionary = _draft.duplicate(true)
	entry["version"] = JOURNAL_SAVE_VERSION
	entry["finished_at_unix"] = int(Time.get_unix_time_from_system())
	_finished.append(entry)
	ResearchTelemetry.record_event("journal_snapshot", {"event": "finish", "entry": entry})
	while _finished.size() > MAX_FINISHED_ENTRIES:
		_finished.pop_front()
	history_changed.emit()
	var coins: int = _award_daily_coins_if_eligible()
	new_draft_at_end()
	return coins


func _award_daily_coins_if_eligible() -> int:
	var day_key: String = _today_key()
	if day_key != _coin_day_key:
		_coin_day_key = day_key
		_finishes_on_coin_day = 0
	var coins: int = 0
	if _finishes_on_coin_day < DAILY_COIN_AMOUNTS.size():
		coins = DAILY_COIN_AMOUNTS[_finishes_on_coin_day]
	_finishes_on_coin_day += 1
	if coins > 0:
		var cur: float = float(Dialogic.VAR.get_variable("gold_coin", 0))
		Dialogic.VAR.set_variable("gold_coin", cur + float(coins))
	return coins


func _today_key() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(dt.year), int(dt.month), int(dt.day)]


func navigate_to_older() -> void:
	if _view_index > 0:
		_view_index -= 1
		view_changed.emit()
		draft_changed.emit()


func navigate_to_newer() -> void:
	if _view_index < _finished.size():
		_view_index += 1
		view_changed.emit()
		draft_changed.emit()


func request_autosave() -> void:
	## Hook for slot save; extras built on next GameSaveManager.save_to_slot.
	pass


func get_save_data() -> Dictionary:
	return {
		"version": JOURNAL_SAVE_VERSION,
		"finished": _finished.duplicate(true),
		"draft": _draft.duplicate(true),
		"view_index": _view_index,
		"coin_day_key": _coin_day_key,
		"finishes_on_coin_day": _finishes_on_coin_day,
	}


func load_save_data(data: Variant) -> void:
	if data == null or not data is Dictionary:
		_finished.clear()
		_coin_day_key = ""
		_finishes_on_coin_day = 0
		_view_index = 0
		new_draft_at_end()
		return
	var d: Dictionary = data as Dictionary
	var v: int = int(d.get("version", 0))
	if v > 0 and d.has("finished"):
		var fin: Variant = d.get("finished", [])
		_finished = fin.duplicate(true) if fin is Array else []
		while _finished.size() > MAX_FINISHED_ENTRIES:
			_finished.pop_front()
	_coin_day_key = str(d.get("coin_day_key", ""))
	_finishes_on_coin_day = clampi(int(d.get("finishes_on_coin_day", 0)), 0, 99)
	_view_index = clampi(int(d.get("view_index", _finished.size())), 0, _finished.size())
	var dr: Variant = d.get("draft", {})
	if dr is Dictionary and not (dr as Dictionary).is_empty():
		_draft = (dr as Dictionary).duplicate(true)
	else:
		_draft = _make_blank_draft()
	if not _draft.has("left"):
		_draft["left"] = _blank_page()
	if not _draft.has("right"):
		_draft["right"] = _blank_page()
	history_changed.emit()
	draft_changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_autosave()
