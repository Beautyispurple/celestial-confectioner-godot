extends CanvasLayer
## Shows session bundle; copy/export summary; main menu continues via parent await + ResearchTelemetry.

signal finished_exit

const GROUP_T := &"research_transparency_active"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 201
	visible = false
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	var title := Label.new()
	title.text = "This session — stored research data"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.96, 0.92))
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.add_theme_color_override("default_color", Color(0.92, 0.9, 0.88))
	rtl.add_theme_font_size_override("normal_font_size", 20)
	scroll.add_child(rtl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var b_print := Button.new()
	b_print.text = "Copy / export summary"
	b_print.custom_minimum_size = Vector2(280, 52)
	b_print.pressed.connect(_on_print)
	row.add_child(b_print)
	var b_menu := Button.new()
	b_menu.text = "Return to main menu"
	b_menu.custom_minimum_size = Vector2(280, 52)
	b_menu.pressed.connect(_on_main_menu)
	row.add_child(b_menu)
	for b in [b_print, b_menu]:
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color(1, 0.96, 0.92))


func run_until_done() -> void:
	if not ResearchTelemetry.is_active():
		return
	add_to_group(GROUP_T)
	visible = true
	var rtl := _find_rtl()
	if rtl:
		rtl.text = _build_bbcode(ResearchTelemetry.get_session_copy_for_transparency())
	await finished_exit
	remove_from_group(GROUP_T)
	visible = false


func _find_rtl() -> RichTextLabel:
	var m := get_child(1) as MarginContainer
	if m == null:
		return null
	var v := m.get_child(0) as VBoxContainer
	if v == null:
		return null
	var sc := v.get_child(1) as ScrollContainer
	if sc == null:
		return null
	return sc.get_child(0) as RichTextLabel


func _nt(plain: String) -> String:
	return plain.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


func _join_lines(parts: PackedStringArray) -> String:
	var s := ""
	for i in parts.size():
		if i > 0:
			s += "\n"
		s += parts[i]
	return s


func _build_bbcode(sess: Dictionary) -> String:
	var fail: Dictionary = sess.get("_failures", {}) as Dictionary
	var lines: PackedStringArray = []
	var ct := ResearchTelemetry.COULD_NOT_TRACK

	lines.append("[b]Timing[/b]")
	var demo: Variant = ResearchTelemetry.get_demo_session_duration_display()
	if sess.get("demo_duration_na", false):
		lines.append("Demo session duration (notice → survey): %s (loaded save — not applicable)" % ct)
	elif demo == null or bool(fail.get("demo_session_duration", false)):
		lines.append("Demo session duration (wall): %s" % ct)
	else:
		lines.append("Demo session duration (wall, sec): %.1f" % float(demo))
	var act: Variant = ResearchTelemetry.get_active_demo_duration_display()
	if act != null and not bool(fail.get("active_demo_duration", false)):
		lines.append("Active duration approx (wall minus pause menu, sec): %.1f" % float(act))
	var ss: float = float(sess.get("survey_duration_sec", 0.0))
	if ss > 0.0:
		lines.append("Survey duration (sec): %.1f" % ss)
	else:
		lines.append("Survey duration (sec): %s" % ct)
	lines.append("")

	lines.append("[b]Pre-play SAM[/b]")
	lines.append(_format_sam_block(sess.get("pre_sam", null)))
	lines.append("")
	lines.append("[b]Post-play SAM (survey)[/b]")
	lines.append(_format_sam_block(sess.get("post_sam", null)))
	lines.append("")

	lines.append("[b]Survey responses[/b]")
	var surv: Variant = sess.get("survey", null)
	if surv is Dictionary and not (surv as Dictionary).is_empty():
		var d: Dictionary = surv as Dictionary
		var keys := d.keys()
		keys.sort()
		for k in keys:
			var val = d[k]
			lines.append(_nt(str(k)) + ": " + _nt(str(val)))
	else:
		lines.append(ct)
	lines.append("")

	lines.append("[b]Gameplay counters (sample)[/b]")
	for k in ["sampler_open", "sampler_close", "breathing_sessions", "breathing_completions", "breathing_skips",
			"breathing_total_sec", "inv_sugar", "inv_water", "inv_chili", "inv_cell_phone",
			"crisis_coping_resolved_count", "pause_close_count", "safety_open_count",
			"save_count", "load_count"]:
		if sess.has(k):
			lines.append("%s: %s" % [k, _nt(str(sess[k]))])
	var sk: Array = sess.keys()
	sk.sort()
	for k in sk:
		var ks := str(k)
		if ks.begins_with("sampler_tab_") or ks.begins_with("minigame_"):
			lines.append("%s: %s" % [ks, _nt(str(sess[k]))])
	lines.append("")

	lines.append("[b]Dialogic text inputs (verbatim)[/b]")
	var dti: Variant = sess.get("dialogic_text_inputs", null)
	if dti is Array:
		var dti_a: Array = dti
		if dti_a.is_empty():
			lines.append(ct)
		else:
			for item in dti_a:
				if item is Dictionary:
					var dd: Dictionary = item
					lines.append("— " + _nt(str(dd.get("prompt", ""))) + " → " + _nt(str(dd.get("text", ""))))
	else:
		lines.append(ct)
	lines.append("")

	lines.append("[b]Journal snapshot (verbatim)[/b]")
	var js: Variant = sess.get("journal_survey_snapshot", null)
	if js is Dictionary:
		lines.append(_nt(JSON.stringify(js)))
	else:
		lines.append(ct)
	lines.append("")

	lines.append("[b]Dragee verbatim[/b]")
	var dv: Variant = sess.get("dragee_verbatim", null)
	if dv is Array:
		var dv_a: Array = dv
		if dv_a.is_empty():
			lines.append("(none or " + ct + ")")
		else:
			for item in dv_a:
				lines.append(_nt(JSON.stringify(item)))
	else:
		lines.append("(none or " + ct + ")")
	lines.append("")

	lines.append("[b]Dialogic milestones[/b]")
	var ms: Variant = sess.get("dialogic_milestones", null)
	if ms is Dictionary:
		lines.append(_nt(JSON.stringify(ms)))
	else:
		lines.append(ct)

	if bool(fail.get("survey_flow", false)):
		lines.append("\n[i]Note: survey flow reported an error; some fields may be incomplete.[/i]")

	return _join_lines(lines)


func _format_sam_block(v: Variant) -> String:
	if v == null:
		return ResearchTelemetry.COULD_NOT_TRACK
	if v is Dictionary:
		var d: Dictionary = v as Dictionary
		if bool(d.get("declined", false)):
			return "Declined (no numeric values stored)"
		return "Valence: %s, Arousal: %s" % [str(d.get("valence", "?")), str(d.get("arousal", "?"))]
	return ResearchTelemetry.COULD_NOT_TRACK


func _on_print() -> void:
	var plain := _build_plain_from_session()
	DisplayServer.clipboard_set(plain)
	var path: String = OS.get_cache_dir().path_join("celestial_research_session.txt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(plain)
		f.close()
		OS.shell_open(path)
	elif OS.is_debug_build():
		push_warning("[ResearchTransparency] Could not write export file")


func _build_plain_from_session() -> String:
	var sess := ResearchTelemetry.get_session_copy_for_transparency()
	sess = sess.duplicate(true)
	sess.erase("_failures")
	return JSON.stringify(sess, "\t")


func _on_main_menu() -> void:
	finished_exit.emit()
