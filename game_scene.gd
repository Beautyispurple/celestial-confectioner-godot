extends Node2D


func _ready() -> void:
	GameSaveManager.apply_stored_options()
	var pending: int = GameSaveManager.consume_pending_load_slot()
	if pending >= 0:
		var err: Error = Dialogic.Save.load(GameSaveManager.slot_to_name(pending))
		if err != OK:
			Dialogic.start("intro_sequence")
		else:
			await get_tree().process_frame
			await get_tree().process_frame
			GameSaveManager.restore_extras_after_load(pending)
	else:
		Dialogic.start("intro_sequence")
