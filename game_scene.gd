extends Node2D


func _ready() -> void:
	CelestialVNState.set_vn_ui_visible(true)
	GameSaveManager.apply_stored_options()
	var pending: int = GameSaveManager.consume_pending_load_slot()

	if pending >= 0:
		var err: Error = Dialogic.Save.load(GameSaveManager.slot_to_name(pending))
		if err == OK:
			ResearchTelemetry.begin_session_from_load()
			ResearchTelemetry.init_if_allowed()
			await get_tree().process_frame
			await get_tree().process_frame
			GameSaveManager.restore_extras_after_load(pending)
			CelestialVNState.resync_dialogic_variables_from_project_defaults()
			CelestialVNState.ensure_sampler_unlock_migrations()
			CelestialVNState.refresh_sampler_slots()
		else:
			await _run_new_game_gates()
			GlobalInventory.reset_new_game_defaults()
			CelestialDrageeDisposal.reset_new_game()
			CelestialVNState.resync_dialogic_variables_from_project_defaults()
			Dialogic.start("intro_sequence")
	else:
		await _run_new_game_gates()
		GlobalInventory.reset_new_game_defaults()
		CelestialDrageeDisposal.reset_new_game()
		CelestialVNState.resync_dialogic_variables_from_project_defaults()
		Dialogic.start("intro_sequence")


func _run_new_game_gates() -> void:
	await _maybe_research_notice()
	await _maybe_consent_pack()
	ResearchTelemetry.init_if_allowed()


func _maybe_research_notice() -> void:
	if not ReleaseMode.IS_RESEARCH_RELEASE:
		return
	var packed: PackedScene = load("res://ui/research_notice_layer.tscn") as PackedScene
	var layer: Node = packed.instantiate()
	add_child(layer)
	await layer.finished_research_notice


func _maybe_consent_pack() -> void:
	var packed: PackedScene = load("res://ui/consent_flow_layer.tscn") as PackedScene
	var layer: Node = packed.instantiate()
	add_child(layer)
	await layer.finished_consent
