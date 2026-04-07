extends Node

## Dialogic slots: slot_1 .. slot_10 under user://dialogic/saves/
const SLOT_COUNT := 10
const EXTRAS_FILE := "celestial_extras.dat"
const OPTIONS_PATH := "user://celestial_options.cfg"

var pending_load_slot: int = -1


func slot_to_name(slot_index: int) -> String:
	return "slot_%d" % (slot_index + 1)


func has_save_in_slot(slot_index: int) -> bool:
	return Dialogic.Save.has_slot(slot_to_name(slot_index))


func get_slot_display_line(slot_index: int) -> String:
	var label := slot_index + 1
	if not has_save_in_slot(slot_index):
		return "Slot %d — Empty" % label
	var info: Dictionary = Dialogic.Save.get_slot_info(slot_to_name(slot_index))
	var when: String = str(info.get("saved_at", "Saved"))
	var dn: String = str(info.get("display_name", "")).strip_edges()
	if not dn.is_empty():
		return "Slot %d — %s · %s" % [label, dn, when]
	return "Slot %d — %s" % [label, when]


func get_slot_default_save_name(slot_index: int) -> String:
	if not has_save_in_slot(slot_index):
		return "Save %d" % (slot_index + 1)
	var info: Dictionary = Dialogic.Save.get_slot_info(slot_to_name(slot_index))
	var dn: String = str(info.get("display_name", "")).strip_edges()
	if not dn.is_empty():
		return dn
	return "Save %d" % (slot_index + 1)


func prepare_load_from_main_menu(slot_index: int) -> void:
	pending_load_slot = slot_index


func consume_pending_load_slot() -> int:
	var s := pending_load_slot
	pending_load_slot = -1
	return s


func save_to_slot(slot_index: int, display_name: String = "") -> Error:
	var sname := slot_to_name(slot_index)
	var dn := display_name.strip_edges()
	if dn.is_empty():
		dn = "Save %d" % (slot_index + 1)
	var err: Error = Dialogic.Save.save(
		sname,
		false,
		Dialogic.Save.ThumbnailMode.NONE,
		{"saved_at": Time.get_datetime_string_from_system(), "display_name": dn}
	)
	if err != OK:
		return err
	return Dialogic.Save.save_file(sname, EXTRAS_FILE, _build_extras())


func delete_slot(slot_index: int) -> Error:
	return Dialogic.Save.delete_slot(slot_to_name(slot_index))


func load_from_slot(slot_index: int) -> Error:
	return Dialogic.Save.load(slot_to_name(slot_index))


func restore_extras_after_load(slot_index: int) -> void:
	var sname := slot_to_name(slot_index)
	var data: Variant = Dialogic.Save.load_file(sname, EXTRAS_FILE, {})
	if data is Dictionary:
		_restore_quests(data.get("quests", {}) as Dictionary)
		_restore_inventory(data.get("inventory", null))


func _build_extras() -> Dictionary:
	return {
		"quests": _quest_snapshot(),
		"inventory": _inventory_snapshot(),
	}


func _quest_snapshot() -> Dictionary:
	return {
		"pools": QuestSystem.pool_state_as_dict(),
		"states": QuestSystem.serialize_quests(),
	}


func _inventory_snapshot() -> Variant:
	var inv := get_node_or_null("/root/GlobalInventory")
	if inv != null and inv.has_method("get_save_data"):
		return inv.call("get_save_data")
	return null


func _restore_quests(qdata: Dictionary) -> void:
	if qdata.is_empty():
		return
	var unique: Array[Quest] = []
	var seen := {}
	for pool in QuestSystem.get_all_pools():
		for q in pool.get_all_quests():
			if not seen.has(q.id):
				seen[q.id] = true
				unique.append(q)
	QuestSystem.reset_pool()
	if qdata.has("pools") and qdata["pools"] is Dictionary:
		QuestSystem.restore_pool_state_from_dict(qdata["pools"], unique)
	if qdata.has("states") and qdata["states"] is Dictionary:
		QuestSystem.deserialize_quests(qdata["states"])


func _restore_inventory(inv_data: Variant) -> void:
	if inv_data == null:
		return
	var inv := get_node_or_null("/root/GlobalInventory")
	if inv != null and inv.has_method("load_save_data"):
		inv.call("load_save_data", inv_data)


func load_options() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(OPTIONS_PATH) != OK:
		return {"fullscreen": false, "master_db": 0.0}
	return {
		"fullscreen": bool(cfg.get_value("audio_video", "fullscreen", false)),
		"master_db": float(cfg.get_value("audio_video", "master_db", 0.0)),
	}


func save_options(fullscreen: bool, master_db: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(OPTIONS_PATH)
	cfg.set_value("audio_video", "fullscreen", fullscreen)
	cfg.set_value("audio_video", "master_db", master_db)
	cfg.save(OPTIONS_PATH)


func apply_options(fullscreen: bool, master_db: float) -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, master_db)


func apply_stored_options() -> void:
	var o := load_options()
	apply_options(o["fullscreen"] as bool, o["master_db"] as float)
