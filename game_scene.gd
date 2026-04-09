extends Node2D


func _ready() -> void:
	CelestialVNState.set_vn_ui_visible(true)
	GameSaveManager.apply_stored_options()
	var pending: int = GameSaveManager.consume_pending_load_slot()
	if pending >= 0:
		var err: Error = Dialogic.Save.load(GameSaveManager.slot_to_name(pending))
		if err != OK:
			GlobalInventory.reset_new_game_defaults()
			CelestialDrageeDisposal.reset_new_game()
			CelestialVNState.resync_dialogic_variables_from_project_defaults()
			await _run_consent_then_intro()
		else:
			await get_tree().process_frame
			await get_tree().process_frame
			GameSaveManager.restore_extras_after_load(pending)
			CelestialVNState.resync_dialogic_variables_from_project_defaults()
			CelestialVNState.ensure_sampler_unlock_migrations()
			CelestialVNState.refresh_sampler_slots()
	else:
		GlobalInventory.reset_new_game_defaults()
		CelestialDrageeDisposal.reset_new_game()
		CelestialVNState.resync_dialogic_variables_from_project_defaults()
		await _run_consent_then_intro()


func _run_consent_then_intro() -> void:
	var packed: PackedScene = load("res://ui/consent_flow_layer.tscn") as PackedScene
	var layer: Node = packed.instantiate()
	add_child(layer)
	await layer.finished_consent
	Dialogic.start("intro_sequence")
