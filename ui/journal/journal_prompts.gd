class_name JournalPrompts
extends RefCounted
## Loads res://data/journal_prompts.json once. Structure: top-level object whose keys are category
## names; each value is an array of prompt strings (hand-edit the JSON; reload game to pick up changes).
## Current data file has 399 prompts (Bubblegum Boundaries has 49 in the source paste); add one there to reach 400 if desired.

const PROMPTS_PATH := "res://data/journal_prompts.json"

static var _loaded: bool = false
static var _data: Dictionary = {}


static func ensure_loaded() -> Error:
	if _loaded:
		return OK
	if not FileAccess.file_exists(PROMPTS_PATH):
		push_error("JournalPrompts: missing %s" % PROMPTS_PATH)
		return ERR_FILE_NOT_FOUND
	var txt := FileAccess.get_file_as_string(PROMPTS_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null or not parsed is Dictionary:
		push_error("JournalPrompts: JSON parse failed")
		return ERR_PARSE_ERROR
	_data = parsed as Dictionary
	_loaded = true
	return OK


static func get_categories() -> PackedStringArray:
	var err: Error = ensure_loaded()
	if err != OK:
		return PackedStringArray()
	var keys: Array = _data.keys()
	keys.sort()
	var out := PackedStringArray()
	for k in keys:
		out.append(str(k))
	return out


static func get_prompt_count(category: String) -> int:
	if ensure_loaded() != OK:
		return 0
	var arr: Variant = _data.get(category, null)
	if arr is Array:
		return (arr as Array).size()
	return 0


## Returns { "category": String, "index": int, "text": String }
static func random_prompt(category: String) -> Dictionary:
	var n: int = get_prompt_count(category)
	if n <= 0:
		return {"category": category, "index": -1, "text": ""}
	var idx: int = randi() % n
	return prompt_by_indices(category, idx)


static func prompt_by_indices(category: String, index: int) -> Dictionary:
	if ensure_loaded() != OK:
		return {"category": category, "index": -1, "text": ""}
	var arr: Variant = _data.get(category, null)
	if not arr is Array:
		return {"category": category, "index": -1, "text": ""}
	var a: Array = arr as Array
	if index < 0 or index >= a.size():
		return {"category": category, "index": -1, "text": ""}
	return {"category": category, "index": index, "text": str(a[index])}
