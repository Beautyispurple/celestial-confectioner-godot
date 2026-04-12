extends CanvasLayer
## First-run consent screens (3 pages + gate). Black background, white text.

signal finished_consent
signal exit_to_main_menu_requested

const GROUP := &"consent_flow_active"
const GROUP_FIRST_RUN := &"first_run_gate_active"

const _SCREEN_TITLES: PackedStringArray = [
	"Before we begin",
	"Safety, distress, and real-world support",
	"Please confirm before playing",
]

## Set in _ready: last index (welcome, safety, gate). Must match _SCREEN_TITLES.size() - 1.
var _final_page_index: int = 0

const _BODY_A := """Welcome.
Celestial Confectioner is a story game designed as peer support practice: a place to try coping tools, navigate relationships, and rehearse responses to real-world pressure—through characters and situations, not through lectures.
It’s meant to feel human: sometimes gentle, sometimes awkward, sometimes intense, sometimes funny—because people’s lives are like that."""

const _BODY_C_MAIN := """This game includes conversations about difficult life experiences. Some characters have lived through traumatic situations, and there may be brief, non-gratuitous descriptions of what they’ve been through—so the story can make room for honest discussion.
Even so, no system can guarantee you won’t feel upset, activated, or overwhelmed.

This game intentionally includes stressful situations without repeated scene-by-scene warnings. Part of the practice is noticing your own signals in real time. Please self-monitor, use the pause menu, step away, or use real-world support when you need them.
If today isn’t a good day for this kind of material, it’s completely okay to exit and come back later."""

const _BODY_E_PROSE := """You’re about to play a story game designed as peer support practice—a place to rehearse coping tools and try responses through characters and situations.
It’s not therapy, not medical advice, not a diagnosis, and not crisis care.

The tools in this game can support reflection and practice, but they are not a replacement for support from a licensed or otherwise qualified professional when you need that kind of help.
This game makes no guarantees and does not claim to treat, cure, or “fix” anyone.

Even with care, parts of the story may feel stressful, upsetting, or activating. This game intentionally does not repeat scene-by-scene warnings.
By continuing, you agree to self-monitor, use the pause menu, and step away or seek real-world support when you need it.
This game is for adults: you must be 18 or older to play.

You’ll hear many perspectives. Not every view is the developer’s, and no character speaks for an entire community.
We aim to be respectful, but we may still miss or misrepresent some realities.
We’ve collaborated with individuals with lived experience in some areas; that collaboration does not make this work an authority over everyone’s experience."""

const _E_REQUIRED_AGREE_LABEL := "I’ve read the above and agree — let’s play"

const _E_CRISIS_ACK_LABEL := "If I’m in crisis, I will use real-world crisis resources (see Pause → Safety & Support)."

var _title_label: Label
var _scroll: ScrollContainer
var _scroll_inner: VBoxContainer
var _footer: VBoxContainer
var _e_notice: Label
var _button_row: HBoxContainer
var _continue_button: Button
var _exit_button: Button
var _collapsible_scene: PackedScene = preload("res://ui/collapsible_section.tscn")

var _page_index: int = 0
var _required_checkbox: CheckBox
var _crisis_ack_checkbox: CheckBox

const _TITLE_FONT_SIZE := 86
const _BODY_FONT_SIZE := 54
const _CHECKBOX_FONT_SIZE := 27
const _HEADER_FONT_SIZE := 27
const _BUTTON_FONT_SIZE := 36
const _E_NOTICE_FONT_SIZE := 23


func _ready() -> void:
	_final_page_index = maxi(0, _SCREEN_TITLES.size() - 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	add_to_group(GROUP)
	add_to_group(GROUP_FIRST_RUN)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.color = Color(0, 0, 0, 1)
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

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	outer.add_child(_title_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_scroll_inner = VBoxContainer.new()
	_scroll_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_inner.add_theme_constant_override("separation", 10)
	_scroll.add_child(_scroll_inner)

	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 8)
	outer.add_child(_footer)

	_e_notice = Label.new()
	_e_notice.visible = false
	_e_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_e_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_e_notice.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_e_notice.add_theme_font_size_override("font_size", _E_NOTICE_FONT_SIZE)
	_e_notice.text = "Please confirm above to continue."
	_footer.add_child(_e_notice)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 20)
	_footer.add_child(_button_row)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.custom_minimum_size = Vector2(420, 86)
	_continue_button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
	_continue_button.pressed.connect(_on_continue_pressed)
	_button_row.add_child(_continue_button)

	_exit_button = Button.new()
	_exit_button.text = "Exit to Main Menu"
	_exit_button.custom_minimum_size = Vector2(420, 86)
	_exit_button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
	_exit_button.pressed.connect(_on_exit_pressed)
	_button_row.add_child(_exit_button)

	_style_light_button(_continue_button)
	_style_light_button(_exit_button)

	_show_page(0)


func _style_light_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.75, 0.75))


func _on_continue_pressed() -> void:
	if _page_index < _final_page_index:
		_show_page(_page_index + 1)
	else:
		remove_from_group(GROUP)
		remove_from_group(GROUP_FIRST_RUN)
		ResearchTelemetry.mark_consent_pack_completed()
		finished_consent.emit()
		queue_free()


func _on_exit_pressed() -> void:
	remove_from_group(GROUP)
	remove_from_group(GROUP_FIRST_RUN)
	exit_to_main_menu_requested.emit()
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _title_font_px(page_idx: int) -> int:
	if page_idx == _final_page_index:
		return int(round(_TITLE_FONT_SIZE * 0.6))
	return int(round(_TITLE_FONT_SIZE * 0.8))


func _show_page(idx: int) -> void:
	_page_index = idx
	_title_label.text = _SCREEN_TITLES[idx]
	_title_label.add_theme_font_size_override("font_size", _title_font_px(idx))

	for c in _scroll_inner.get_children():
		c.queue_free()
	_required_checkbox = null
	_crisis_ack_checkbox = null

	if idx == _final_page_index:
		var g_btn: int = int(round(_BUTTON_FONT_SIZE * 0.6))
		var g_notice: int = int(round(_E_NOTICE_FONT_SIZE * 0.6))
		_continue_button.text = "I understand and agree — continue"
		_continue_button.disabled = true
		_continue_button.custom_minimum_size = Vector2(int(round(420 * 0.6)), int(round(86 * 0.6)))
		_continue_button.add_theme_font_size_override("font_size", g_btn)
		_exit_button.visible = true
		_exit_button.custom_minimum_size = Vector2(int(round(420 * 0.6)), int(round(86 * 0.6)))
		_exit_button.add_theme_font_size_override("font_size", g_btn)
		_e_notice.visible = true
		_e_notice.add_theme_font_size_override("font_size", g_notice)
		_build_gate_page()
	else:
		_continue_button.text = "Continue"
		_continue_button.disabled = false
		_continue_button.custom_minimum_size = Vector2(420, 86)
		_continue_button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
		_exit_button.custom_minimum_size = Vector2(420, 86)
		_exit_button.add_theme_font_size_override("font_size", _BUTTON_FONT_SIZE)
		_e_notice.visible = false
		_e_notice.add_theme_font_size_override("font_size", _E_NOTICE_FONT_SIZE)
		_build_body_pages(idx)

	await get_tree().process_frame
	if _scroll:
		_scroll.scroll_vertical = 0


func _rtl(body_px: int) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", Color.WHITE)
	rtl.add_theme_color_override("font_selected_color", Color(0.65, 0.85, 1.0))
	rtl.add_theme_font_size_override("normal_font_size", body_px)
	if not rtl.meta_clicked.is_connected(_on_rich_meta_clicked):
		rtl.meta_clicked.connect(_on_rich_meta_clicked)
	return rtl


func _on_rich_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _build_body_pages(idx: int) -> void:
	var body_sm: int = int(round(_BODY_FONT_SIZE * 0.8))
	var rtl := _rtl(body_sm)
	match idx:
		0:
			rtl.text = "[center]" + _BODY_A.replace("\n\n", "[br]") + "[/center]"
			_scroll_inner.add_child(rtl)
		1:
			rtl.text = "[center]" + _BODY_C_MAIN.replace("\n\n", "[br]") + "[/center]"
			_scroll_inner.add_child(rtl)
			var col: Node = _collapsible_scene.instantiate()
			_scroll_inner.add_child(col)
			if col.has_method(&"set_title"):
				col.call(&"set_title", "Crisis & support resources (USA)")
			if col.has_method(&"set_body_bbcode"):
				col.call(&"set_body_bbcode", "[center]" + CrisisResourcesText.USA_CRISIS_RESOURCES_BBCODE + "[/center]")
			var header_px: int = int(round(_HEADER_FONT_SIZE * 1.5))
			_style_collapsible(col, header_px, body_sm)
		_:
			rtl.text = ""
			_scroll_inner.add_child(rtl)


func _style_collapsible(col: Node, header_px: int = _HEADER_FONT_SIZE, body_px: int = _BODY_FONT_SIZE) -> void:
	var header: Button = col.get_node_or_null("HeaderButton") as Button
	if header:
		header.add_theme_color_override("font_color", Color.WHITE)
		header.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85))
		header.add_theme_font_size_override("font_size", header_px)
	var rt: RichTextLabel = col.get_node_or_null("BodyMargin/BodyRichText") as RichTextLabel
	if rt:
		rt.add_theme_color_override("default_color", Color.WHITE)
		rt.add_theme_color_override("font_selected_color", Color(0.65, 0.85, 1.0))
		rt.add_theme_font_size_override("normal_font_size", body_px)


func _make_checkbox_icons() -> Dictionary:
	var size := 30
	var border := Color(1, 1, 1, 1)
	var fill := Color(1, 1, 1, 1)

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


func _build_gate_page() -> void:
	var g_body: int = int(round(_BODY_FONT_SIZE * 0.6))
	var g_chk: int = int(round(_CHECKBOX_FONT_SIZE * 0.6))
	var icons := _make_checkbox_icons()
	var prose := _rtl(g_body)
	prose.text = "[center]" + _BODY_E_PROSE.replace("\n\n", "[br][br]").replace("\n", " ") + "[/center]"
	_scroll_inner.add_child(prose)

	_required_checkbox = CheckBox.new()
	_required_checkbox.text = _E_REQUIRED_AGREE_LABEL
	_required_checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_required_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_required_checkbox.add_theme_font_size_override("font_size", g_chk)
	_required_checkbox.add_theme_color_override("font_color", Color.WHITE)
	_required_checkbox.add_theme_color_override("font_pressed_color", Color.WHITE)
	_required_checkbox.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
	_required_checkbox.add_theme_color_override("font_focus_color", Color.WHITE)
	_required_checkbox.add_theme_icon_override("unchecked", icons["unchecked"])
	_required_checkbox.add_theme_icon_override("checked", icons["checked"])
	_required_checkbox.add_theme_constant_override("check_v_offset", 2)
	_required_checkbox.toggled.connect(_on_e_checkbox_changed)
	_scroll_inner.add_child(_required_checkbox)

	_crisis_ack_checkbox = CheckBox.new()
	_crisis_ack_checkbox.text = _E_CRISIS_ACK_LABEL
	_crisis_ack_checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crisis_ack_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crisis_ack_checkbox.add_theme_font_size_override("font_size", g_chk)
	_crisis_ack_checkbox.add_theme_color_override("font_color", Color.WHITE)
	_crisis_ack_checkbox.add_theme_color_override("font_pressed_color", Color.WHITE)
	_crisis_ack_checkbox.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
	_crisis_ack_checkbox.add_theme_icon_override("unchecked", icons["unchecked"])
	_crisis_ack_checkbox.add_theme_icon_override("checked", icons["checked"])
	_crisis_ack_checkbox.add_theme_constant_override("check_v_offset", 2)
	_crisis_ack_checkbox.toggled.connect(_on_e_checkbox_changed)
	_scroll_inner.add_child(_crisis_ack_checkbox)

	_refresh_e_primary()


func _on_e_checkbox_changed(_pressed: bool) -> void:
	_refresh_e_primary()


func _refresh_e_primary() -> void:
	var req: bool = _required_checkbox != null and _required_checkbox.button_pressed
	var crisis: bool = _crisis_ack_checkbox != null and _crisis_ack_checkbox.button_pressed
	_continue_button.disabled = not (req and crisis)
