extends CanvasLayer

signal finished_research_notice
signal exit_to_main_menu_requested

const GROUP_FIRST_RUN := &"first_run_gate_active"
const _SAM_SCENE := preload("res://ui/research_sam_panel.tscn")

const _TITLE := "Research build — before you play"
const _BODY_BB := """Thank you for helping try this demo.

This is the [b]research[/b] build. It may collect [b]anonymous gameplay metrics[/b]. It may collect [b]survey responses[/b], including free-text answers. It may collect [b]text you type in-game[/b] (for example in the journal or other free-text prompts we instrument), as part of the research dataset.

Data are collected [b]without identifying information[/b] — no names, no contact details, no IDs we assign to you as a person.

When you finish playing, there is a short survey. After that, you may open a screen that shows what was stored for [b]this session[/b], including verbatim text where applicable.

The final public release will [b]not[/b] collect these research items.

If you need crisis or support resources at any time, use [b]Pause → Safety & Support[/b]."""

const _CHECK_LABEL := "I understand and agree to research data collection for this build (metrics, survey, and in-game text as described above)."

const _TITLE_FONT_SIZE := 69 # 0.8×86
const _BODY_FONT_SIZE := 43 # 0.8×54
const _CHECKBOX_FONT_SIZE := 22 # 0.8×27
const _BUTTON_FONT_SIZE := 29 # 0.8×36

var _continue_button: Button
var _checkbox: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 105
	add_to_group(GROUP_FIRST_RUN)
	if ReleaseMode.IS_RESEARCH_RELEASE:
		ResearchTelemetry.mark_research_notice_shown()

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.color = Color(0.14, 0.09, 0.07, 1.0)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 16)
	margin.add_child(outer)

	var title_label := Label.new()
	title_label.text = _TITLE
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
	title_label.add_theme_font_size_override("font_size", _TITLE_FONT_SIZE)
	outer.add_child(title_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var scroll_inner := VBoxContainer.new()
	scroll_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_inner)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", Color(1.0, 0.96, 0.92))
	rtl.add_theme_color_override("font_selected_color", Color(0.85, 0.75, 0.55))
	rtl.add_theme_font_size_override("normal_font_size", _BODY_FONT_SIZE)
	if not rtl.meta_clicked.is_connected(_on_rich_meta_clicked):
		rtl.meta_clicked.connect(_on_rich_meta_clicked)
	rtl.text = "[center]" + _BODY_BB + "[/center]"
	scroll_inner.add_child(rtl)

	var icons := _make_checkbox_icons()
	_checkbox = CheckBox.new()
	_checkbox.text = _CHECK_LABEL
	_checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_checkbox.add_theme_font_size_override("font_size", _CHECKBOX_FONT_SIZE)
	_checkbox.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
	_checkbox.add_theme_color_override("font_pressed_color", Color(1.0, 0.96, 0.92))
	_checkbox.add_theme_color_override("font_hover_color", Color(0.98, 0.94, 0.88))
	_checkbox.add_theme_icon_override("unchecked", icons["unchecked"])
	_checkbox.add_theme_icon_override("checked", icons["checked"])
	_checkbox.add_theme_constant_override("check_v_offset", 2)
	_checkbox.toggled.connect(_on_checkbox_toggled)
	scroll_inner.add_child(_checkbox)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	outer.add_child(footer)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	footer.add_child(button_row)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(336, 69)
	_continue_button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
	_continue_button.disabled = true
	_continue_button.pressed.connect(_on_continue_pressed)
	button_row.add_child(_continue_button)

	var exit_button := Button.new()
	exit_button.text = "Exit to Main Menu"
	exit_button.custom_minimum_size = Vector2(336, 69)
	exit_button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
	exit_button.pressed.connect(_on_exit_pressed)
	button_row.add_child(exit_button)

	_style_warm_button(_continue_button)
	_style_warm_button(exit_button)


func _style_warm_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.92))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.9, 0.85))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.78, 0.7))


func _on_rich_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _make_checkbox_icons() -> Dictionary:
	var size := 30
	var border := Color(1, 0.92, 0.85, 1)
	var fill := Color(1, 0.92, 0.85, 1)

	var img_off := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img_off.fill(Color(0, 0, 0, 0))
	for x in size:
		img_off.set_pixel(x, 0, border)
		img_off.set_pixel(x, size - 1, border)
	for y in size:
		img_off.set_pixel(0, y, border)
		img_off.set_pixel(size - 1, y, border)
	var tex_off := ImageTexture.create_from_image(img_off)

	var img_on := img_off.duplicate()
	for x in range(7, size - 7):
		for y in range(7, size - 7):
			img_on.set_pixel(x, y, fill)
	var tex_on := ImageTexture.create_from_image(img_on)

	return {"unchecked": tex_off, "checked": tex_on}


func _on_checkbox_toggled(_pressed: bool) -> void:
	_continue_button.disabled = not _checkbox.button_pressed


func _on_continue_pressed() -> void:
	if not _checkbox.button_pressed:
		return
	_continue_button.disabled = true
	_checkbox.disabled = true
	_run_sam_and_finish()


func _run_sam_and_finish() -> void:
	ResearchConsentState.record_research_notice_accepted()
	var sam: PanelContainer = _SAM_SCENE.instantiate() as PanelContainer
	sam.configure(
		"Before you play: how do you feel right now?",
		"You can decline this block; we will not store numeric ratings if you do."
	)
	sam.set_anchors_preset(Control.PRESET_CENTER)
	sam.offset_left = -460
	sam.offset_top = -300
	sam.offset_right = 460
	sam.offset_bottom = 300
	add_child(sam)
	var res: Variant = await sam.finished
	if res is Dictionary:
		ResearchTelemetry.record_event("pre_sam", res)
	sam.queue_free()
	remove_from_group(GROUP_FIRST_RUN)
	finished_research_notice.emit()
	queue_free()


func _on_exit_pressed() -> void:
	remove_from_group(GROUP_FIRST_RUN)
	exit_to_main_menu_requested.emit()
	get_tree().change_scene_to_file("res://main_menu.tscn")
