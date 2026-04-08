extends Node
## Marzi's bag: stack counts persisted via GameSaveManager celestial_extras.dat.

signal inventory_changed()

const ITEM_SUGAR := "sugar"
const ITEM_WATER := "water"
const ITEM_CHILI := "chili"
const ITEM_PHONE := "cell_phone"

var _stacks: Dictionary = {}


func _ready() -> void:
	pass


func reset_new_game_defaults() -> void:
	_stacks = {
		ITEM_SUGAR: 10,
		ITEM_WATER: 10,
		ITEM_CHILI: 10,
		ITEM_PHONE: 1,
	}
	inventory_changed.emit()


func get_count(item_id: String) -> int:
	return clampi(int(_stacks.get(item_id, 0)), 0, 9999)


func get_save_data() -> Dictionary:
	return _stacks.duplicate(true)


func load_save_data(data: Variant) -> void:
	if data is Dictionary:
		_stacks.clear()
		for k in (data as Dictionary).keys():
			_stacks[str(k)] = int((data as Dictionary)[k])
		inventory_changed.emit()


func can_throw_away(item_id: String) -> bool:
	if item_id == ITEM_PHONE:
		return false
	return get_count(item_id) > 0


func throw_away_one(item_id: String) -> bool:
	if not can_throw_away(item_id):
		return false
	_stacks[item_id] = get_count(item_id) - 1
	inventory_changed.emit()
	return true


func eat_sugar() -> bool:
	if get_count(ITEM_SUGAR) <= 0:
		return false
	_stacks[ITEM_SUGAR] = get_count(ITEM_SUGAR) - 1
	CelestialVNState.apply_direct_social_delta(1)
	inventory_changed.emit()
	return true


func drink_water() -> bool:
	if get_count(ITEM_WATER) <= 0:
		return false
	_stacks[ITEM_WATER] = get_count(ITEM_WATER) - 1
	CelestialVNState.apply_direct_panic_delta(-10)
	inventory_changed.emit()
	return true


func eat_chili() -> bool:
	if get_count(ITEM_CHILI) <= 0:
		return false
	_stacks[ITEM_CHILI] = get_count(ITEM_CHILI) - 1
	CelestialVNState.apply_direct_panic_delta(4)
	inventory_changed.emit()
	return true


func call_friend() -> bool:
	if get_count(ITEM_PHONE) <= 0:
		return false
	CelestialVNState.apply_social_drain(4)
	return true
