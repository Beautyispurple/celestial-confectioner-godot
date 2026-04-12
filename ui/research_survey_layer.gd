extends CanvasLayer
## Post-demo survey (sections 0→G). Submits via ResearchTelemetry.submit_survey_answers.

const GROUP_SURVEY := &"research_survey_active"
const _SAM_SCENE := preload("res://ui/research_sam_panel.tscn")

var _answers: Dictionary = {}
var _title: Label
var _scroll_box: VBoxContainer
var _btn_back: Button
var _btn_next: Button
var _footer: HBoxContainer

var _next_go: bool = false
var _section_index: int = 0
var _d1_value: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	visible = false
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.06, 0.1, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 720)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.16, 0.98)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_top = 16
	sb.content_margin_right = 20
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(1, 0.96, 0.92))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_scroll_box = VBoxContainer.new()
	_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_box.add_theme_constant_override("separation", 14)
	scroll.add_child(_scroll_box)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 24)
	outer.add_child(_footer)
	_btn_back = Button.new()
	_btn_back.text = "Back"
	_btn_back.custom_minimum_size = Vector2(160, 48)
	_btn_back.visible = false
	_footer.add_child(_btn_back)
	_btn_next = Button.new()
	_btn_next.text = "Next"
	_btn_next.custom_minimum_size = Vector2(220, 48)
	_btn_next.pressed.connect(_on_next_pressed)
	_footer.add_child(_btn_next)
	for b in [_btn_back, _btn_next]:
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color(1, 0.96, 0.92))


func run_survey() -> void:
	if not ResearchTelemetry.is_active():
		return
	add_to_group(GROUP_SURVEY)
	visible = true
	_answers.clear()
	_section_index = 0
	await _run_all_sections()
	ResearchTelemetry.submit_survey_answers(_answers)
	remove_from_group(GROUP_SURVEY)
	visible = false


func _on_next_pressed() -> void:
	_next_go = true


func _await_next() -> void:
	_next_go = false
	_btn_next.disabled = false
	while not _next_go:
		await get_tree().process_frame


func _clear_scroll() -> void:
	for c in _scroll_box.get_children():
		c.queue_free()


func _lbl(t: String, size: int = 22) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.88))
	return l


func _run_all_sections() -> void:
	while _section_index < 9:
		match _section_index:
			0:
				await _page_sam_post()
			1:
				await _page_a()
			2:
				await _page_b1()
			3:
				await _page_b2()
			4:
				await _page_c()
			5:
				await _page_d()
			6:
				await _page_e()
			7:
				await _page_f()
			8:
				await _page_g()
		_section_index += 1


func _page_sam_post() -> void:
	_title.text = "Section 0 — Post-play mood"
	_btn_back.visible = false
	_btn_next.visible = false
	_clear_scroll()
	var sam: PanelContainer = _SAM_SCENE.instantiate() as PanelContainer
	sam.configure("How do you feel right now?", "")
	_scroll_box.add_child(sam)
	var res: Variant = await sam.finished
	if res is Dictionary:
		_answers["post_sam"] = res
	sam.queue_free()
	_btn_next.visible = true
	_btn_next.text = "Next"


func _page_a() -> void:
	_title.text = "Section A — Light context"
	_clear_scroll()
	_scroll_box.add_child(_lbl("How often do you play video games?", 20))
	_add_single_choice("A1", ResearchSurveyProtocol.A1_PLAY_FREQ)
	_scroll_box.add_child(_lbl("Age range", 20))
	_add_option_row("A2", ResearchSurveyProtocol.AGE_BANDS)
	_scroll_box.add_child(_lbl("Gender (optional)", 20))
	_add_option_row("A3", ResearchSurveyProtocol.GENDER_CHOICES)
	_scroll_box.add_child(_lbl("Optional: self-describe (only if you wish)", 18))
	var le := LineEdit.new()
	le.placeholder_text = "Optional"
	le.name = "A3_free"
	_scroll_box.add_child(le)
	_btn_next.text = "Next"
	await _await_next()
	_answers["A1"] = _read_button_group("A1")
	_answers["A2"] = _read_option("A2")
	_answers["A3"] = _read_option("A3")
	_answers["A3_free"] = le.text.strip_edges()


func _page_b1() -> void:
	_title.text = "Section B — Gameplay (1/2)"
	_clear_scroll()
	_add_likert("B1", "Overall, the demo was enjoyable.")
	_add_likert("B2", "I understood what to do most of the time.")
	_add_likert("B3", "The pacing felt right for the time I spent.")
	_add_likert("B4", "The challenge felt appropriate (not too easy or too hard).")
	_add_likert("B5", "I was interested in the characters and story.")
	_add_likert("B6", "Visuals and sound fit the mood of the game.")
	_add_likert("B7", "Controls and interface (outside the breathing exercises) felt clear and responsive.")
	_add_likert("B8", "The demo ran smoothly for me.")
	_btn_next.text = "Next"
	await _await_next()
	_collect_likert_keys(["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8"])


func _page_b2() -> void:
	_title.text = "Section B — Gameplay (2/2)"
	_clear_scroll()
	_add_likert("B9", "The controls for the breathing minigames were easy to use.")
	_add_likert("B10", "The breathing minigames made it clear what I should do at each step.")
	_add_likert("B11", "The optional tools in the Sampler (besides the breathing exercises) felt worth trying.")
	_add_likert("B12", "The optional Sampler tools were easy to understand.")
	_scroll_box.add_child(_lbl("Voice acting", 20))
	_scroll_box.add_child(
		_lbl("Did the voice acting add to or subtract from your experience?", 18)
	)
	_add_single_choice("VA_impact", ResearchSurveyProtocol.VA_IMPACT_CHOICES)
	_add_multiline("VA_desc", "Please describe (optional).")
	_btn_next.text = "Next"
	await _await_next()
	_collect_likert_keys(["B9", "B10", "B11", "B12"])
	_answers["VA_impact"] = _read_button_group("VA_impact")
	var va_te := _scroll_box.find_child("VA_desc", true, false) as TextEdit
	_answers["VA_desc"] = va_te.text.strip_edges() if va_te else ""


func _page_c() -> void:
	_title.text = "Section C — While playing"
	_clear_scroll()
	_add_likert("C1", "While playing, I felt calm.")
	_add_likert("C2", "While playing, I felt stressed or tense.")
	_add_likert("C3", "I was absorbed in the game (lost track of time).")
	_add_likert("C4", "The demo produced meaningful emotional reactions for me (pleasant or unpleasant).")
	_add_likert("C5", "Playing helped take my mind off other worries, at least for a while.")
	_btn_next.text = "Next"
	await _await_next()
	_collect_likert_keys(["C1", "C2", "C3", "C4", "C5"])


func _page_d() -> void:
	_title.text = "Section D — Safety"
	_clear_scroll()
	_scroll_box.add_child(_lbl("At any point, did the demo feel upsetting or overwhelming in a way you did not want?", 20))
	_add_single_choice("D1", ResearchSurveyProtocol.D1_UPSET)
	_btn_next.text = "Next"
	await _await_next()
	_d1_value = str(_read_button_group("D1"))
	_answers["D1"] = _d1_value
	if _d1_value == "No":
		_answers["D1b"] = ""
	else:
		_clear_scroll()
		_scroll_box.add_child(_lbl("Optional: say more (you can skip).", 20))
		var ml := TextEdit.new()
		ml.custom_minimum_size = Vector2(0, 140)
		ml.placeholder_text = "Optional"
		ml.name = "D1b_field"
		_scroll_box.add_child(ml)
		_btn_next.text = "Next"
		await _await_next()
		var te := _scroll_box.find_child("D1b_field", true, false) as TextEdit
		_answers["D1b"] = te.text.strip_edges() if te else ""


func _page_e() -> void:
	_title.text = "Section E — Open text (all optional)"
	_clear_scroll()
	_add_multiline("E1", "What was the best moment in the demo for you?")
	_add_multiline("E2", "What was most confusing, frustrating, or broken?")
	_add_multiline("E3", "If you could change one thing for the next build, what would it be?")
	_add_multiline("E4", "Did anything in the story or gameplay feel personally resonant?")
	_add_multiline("E5", "Is there anything we should know to make this experience safer or more comfortable for players?")
	_btn_next.text = "Next"
	await _await_next()
	for k in ["E1", "E2", "E3", "E4", "E5"]:
		var te := _scroll_box.find_child(k, true, false) as TextEdit
		if te:
			_answers[k] = te.text.strip_edges()


func _page_f() -> void:
	_title.text = "Section F — Protagonist connection"
	_clear_scroll()
	_add_likert("F_a1", "When I was helping Marzi handle situations in the demo, I felt connected to her.")
	_btn_next.text = "Next"
	await _await_next()
	_collect_likert_keys(["F_a1"])


func _page_g() -> void:
	_title.text = "Section G — Continue intent"
	_clear_scroll()
	_scroll_box.add_child(_lbl("How likely are you to play more of this game when it’s available? (0 = not at all, 10 = very likely)", 20))
	var hb := HBoxContainer.new()
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 10
	sl.step = 1
	sl.value = 5
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.name = "G1_slider"
	var val := Label.new()
	val.text = "5"
	val.custom_minimum_size = Vector2(36, 0)
	sl.value_changed.connect(func(v: float) -> void:
		val.text = str(int(v))
	)
	hb.add_child(sl)
	hb.add_child(val)
	_scroll_box.add_child(hb)
	_btn_next.text = "Submit"
	await _await_next()
	var s := _scroll_box.find_child("G1_slider", true, false) as HSlider
	if s:
		_answers["G1"] = int(s.value)


func _add_single_choice(key: String, options: PackedStringArray) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for o in options:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = o
		b.name = "sc_%s_%s" % [key, o]
		vb.add_child(b)
	_scroll_box.add_child(vb)
	vb.name = "group_%s" % key


func _read_button_group(key: String) -> String:
	var vb := _scroll_box.find_child("group_%s" % key, true, false) as VBoxContainer
	if vb == null:
		return ""
	for c in vb.get_children():
		if c is Button and (c as Button).button_pressed:
			return (c as Button).text
	return ""


func _add_option_row(key: String, options: PackedStringArray) -> void:
	var ob := OptionButton.new()
	for o in options:
		ob.add_item(o)
	ob.name = "opt_%s" % key
	_scroll_box.add_child(ob)


func _read_option(key: String) -> String:
	var ob := _scroll_box.find_child("opt_%s" % key, true, false) as OptionButton
	if ob == null or ob.selected < 0:
		return ""
	return ob.get_item_text(ob.selected)


func _add_likert(ans_key: String, question: String) -> void:
	_scroll_box.add_child(_lbl(question, 19))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.name = "likert_%s" % ans_key
	var group := ButtonGroup.new()
	for i in ResearchSurveyProtocol.LIKERT_7.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = str(i + 1)
		b.tooltip_text = ResearchSurveyProtocol.LIKERT_7[i]
		b.custom_minimum_size = Vector2(48, 40)
		hb.add_child(b)
	_scroll_box.add_child(hb)


func _collect_likert_keys(keys: Array) -> void:
	for k in keys:
		var hb := _scroll_box.find_child("likert_%s" % k, true, false) as HBoxContainer
		if hb == null:
			continue
		var idx := 0
		for c in hb.get_children():
			idx += 1
			if c is Button and (c as Button).button_pressed:
				_answers[k] = idx
				break


func _add_multiline(name_key: String, question: String) -> void:
	_scroll_box.add_child(_lbl(question, 19))
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(0, 100)
	te.name = name_key
	_scroll_box.add_child(te)
