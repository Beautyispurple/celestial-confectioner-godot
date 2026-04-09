extends CanvasLayer
## First-run consent screens A–E (new game only). Black background, white text.

signal finished_consent
signal exit_to_main_menu_requested

const GROUP := &"consent_flow_active"

const _SCREEN_TITLES: PackedStringArray = [
	"Before we begin",
	"What this game can’t do",
	"Safety, distress, and real-world support",
	"Choices, skills, and consequences",
	"Please confirm before playing",
]

const _BODY_A := """Welcome.
Celestial Confectioner is a story game designed as peer support practice: a place to try coping tools, navigate relationships, and rehearse responses to real-world pressure—through characters and situations, not through lectures.
It’s meant to feel human: sometimes gentle, sometimes awkward, sometimes intense, sometimes funny—because people’s lives are like that."""

const _BODY_B := """A quick boundary, said with care:
This game is not therapy, not medical advice, and not a diagnosis. It is not crisis care.
The tools in this game can support reflection and practice, but they are not a replacement for support from a licensed or otherwise qualified professional when you need that kind of help.
Think of this as a companion and a practice space, not a clinic."""

const _BODY_C_MAIN := """This game includes conversations about difficult life experiences. Some characters have lived through traumatic situations, and there may be brief, non-gratuitous descriptions of what they’ve been through—so the story can make room for honest discussion.
Even so, no system can guarantee you won’t feel upset, activated, or overwhelmed.
Important: this game intentionally includes stressful situations without repeated scene-by-scene warnings. Part of the practice is noticing your own signals in real time. By continuing, you agree to self-monitor and use the pause menu and real-world support when you need them.
If today isn’t a good day for this kind of material, it’s completely okay to exit and come back later."""

const _BODY_D := """This game is not here to judge you. There are no choices meant to label you as “good” or “bad.”
At the same time, choices can still have realistic consequences—stress, awkwardness, conflict, or regret—because that’s how pressure and limited capacity often work in real life, especially before skills feel available.
The coping tools here are inspired by real-world skills, simplified for play. They can be helpful practice, but they won’t work for everyone in every moment."""

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

# Historical per-line required confirmations (replaced with the single prose block above):
# - Peer support / story, not therapy and not medical care.
# - Tools not a replacement for qualified professional help when needed.
# - Distress/triggering possible (previously referenced “content options”).
# - Stressful situations; no repeated scene-by-scene warnings; self-monitor; use pause + real-world support.
# - 18+.
# - No guarantees / no claim to treat, cure, fix.
# - Many perspectives; not all views = developer; no character speaks for a whole community.
# - Diverse experiences; possible miss/misrepresentation; aim is respect, not definitiveness.
# - Lived-experience collaboration; not authoritative for everyone.

const _E_REQUIRED_AGREE_LABEL := "I’ve read the above and agree — let’s play"

const _OPTIONAL_CHECK_LABEL := "Optional: If I’m in crisis, I’ll use real-world crisis resources (see Pause → Safety & Support)."

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
var _optional_checkbox: CheckBox

const _TITLE_FONT_SIZE := 96
const _BODY_FONT_SIZE := 60
const _CHECKBOX_FONT_SIZE := 30
const _HEADER_FONT_SIZE := 30
const _BUTTON_FONT_SIZE := 40


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	add_to_group(GROUP)

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
	_title_label.add_theme_font_size_override("font_size", _TITLE_FONT_SIZE)
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
	_e_notice.add_theme_font_size_override("font_size", 26)
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
	if _page_index < 4:
		_show_page(_page_index + 1)
	else:
		remove_from_group(GROUP)
		finished_consent.emit()
		queue_free()


func _on_exit_pressed() -> void:
	remove_from_group(GROUP)
	exit_to_main_menu_requested.emit()
	queue_free()
	get_tree().change_scene_to_file("res://main_menu.tscn")


func _show_page(idx: int) -> void:
	_page_index = idx
	_title_label.text = _SCREEN_TITLES[idx]

	for c in _scroll_inner.get_children():
		c.queue_free()
	_required_checkbox = null
	_optional_checkbox = null

	if idx == 4:
		_continue_button.text = "I understand and agree — continue"
		_continue_button.disabled = true
		_exit_button.visible = true
		_e_notice.visible = true
		_build_page_e()
	else:
		_continue_button.text = "Continue"
		_continue_button.disabled = false
		_e_notice.visible = false
		_build_body_pages(idx)

	await get_tree().process_frame
	if _scroll:
		_scroll.scroll_vertical = 0


func _rtl() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", Color.WHITE)
	rtl.add_theme_color_override("font_selected_color", Color(0.65, 0.85, 1.0))
	rtl.add_theme_font_size_override("normal_font_size", _BODY_FONT_SIZE)
	if not rtl.meta_clicked.is_connected(_on_rich_meta_clicked):
		rtl.meta_clicked.connect(_on_rich_meta_clicked)
	return rtl


func _on_rich_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _build_body_pages(idx: int) -> void:
	var rtl := _rtl()
	match idx:
		0:
			rtl.text = "[center]" + _BODY_A.replace("\n\n", "[br]") + "[/center]"
		1:
			rtl.text = "[center]" + _BODY_B.replace("\n\n", "[br]") + "[/center]"
		2:
			rtl.text = "[center]" + _BODY_C_MAIN.replace("\n\n", "[br]") + "[/center]"
			_scroll_inner.add_child(rtl)
			var col: Node = _collapsible_scene.instantiate()
			_scroll_inner.add_child(col)
			if col.has_method(&"set_title"):
				col.call(&"set_title", "Crisis & support resources (USA)")
			if col.has_method(&"set_body_bbcode"):
				col.call(&"set_body_bbcode", "[center]" + CrisisResourcesText.USA_CRISIS_RESOURCES_BBCODE + "[/center]")
			_style_collapsible(col)
			return
		3:
			rtl.text = "[center]" + _BODY_D.replace("\n\n", "[br]") + "[/center]"
		_:
			rtl.text = ""
	_scroll_inner.add_child(rtl)


func _style_collapsible(col: Node) -> void:
	var header: Button = col.get_node_or_null("HeaderButton") as Button
	if header:
		header.add_theme_color_override("font_color", Color.WHITE)
		header.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85))
		header.add_theme_font_size_override("font_size", _HEADER_FONT_SIZE)
	var rt: RichTextLabel = col.get_node_or_null("BodyMargin/BodyRichText") as RichTextLabel
	if rt:
		rt.add_theme_color_override("default_color", Color.WHITE)
		rt.add_theme_color_override("font_selected_color", Color(0.65, 0.85, 1.0))
		rt.add_theme_font_size_override("normal_font_size", _BODY_FONT_SIZE)


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
	# simple filled square mark for high contrast
	for x in range(7, size - 7):
		for y in range(7, size - 7):
			img_on.set_pixel(x, y, fill)
	var tex_on := ImageTexture.create_from_image(img_on)

	return {"unchecked": tex_off, "checked": tex_on}


func _build_page_e() -> void:
	var icons := _make_checkbox_icons()
	var prose := _rtl()
	prose.text = "[center]" + _BODY_E_PROSE.replace("\n\n", "[br][br]").replace("\n", " ") + "[/center]"
	_scroll_inner.add_child(prose)

	_required_checkbox = CheckBox.new()
	_required_checkbox.text = _E_REQUIRED_AGREE_LABEL
	_required_checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_required_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_required_checkbox.add_theme_font_size_override("font_size", _CHECKBOX_FONT_SIZE)
	_required_checkbox.add_theme_color_override("font_color", Color.WHITE)
	_required_checkbox.add_theme_color_override("font_pressed_color", Color.WHITE)
	_required_checkbox.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
	_required_checkbox.add_theme_color_override("font_focus_color", Color.WHITE)
	_required_checkbox.add_theme_icon_override("unchecked", icons["unchecked"])
	_required_checkbox.add_theme_icon_override("checked", icons["checked"])
	_required_checkbox.add_theme_constant_override("check_v_offset", 2)
	_required_checkbox.toggled.connect(_on_e_checkbox_changed)
	_scroll_inner.add_child(_required_checkbox)

	_optional_checkbox = CheckBox.new()
	_optional_checkbox.text = _OPTIONAL_CHECK_LABEL
	_optional_checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_optional_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_optional_checkbox.add_theme_font_size_override("font_size", _CHECKBOX_FONT_SIZE)
	_optional_checkbox.add_theme_color_override("font_color", Color.WHITE)
	_optional_checkbox.add_theme_color_override("font_pressed_color", Color.WHITE)
	_optional_checkbox.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
	_optional_checkbox.add_theme_icon_override("unchecked", icons["unchecked"])
	_optional_checkbox.add_theme_icon_override("checked", icons["checked"])
	_optional_checkbox.add_theme_constant_override("check_v_offset", 2)
	_optional_checkbox.toggled.connect(_on_e_checkbox_changed)
	_scroll_inner.add_child(_optional_checkbox)

	_refresh_e_primary()


func _on_e_checkbox_changed(_pressed: bool) -> void:
	_refresh_e_primary()


func _refresh_e_primary() -> void:
	_continue_button.disabled = not (_required_checkbox and _required_checkbox.button_pressed)
