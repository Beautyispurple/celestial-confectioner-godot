extends PanelContainer
## SAM: Valence + Arousal, 9 points each (pictorial row = gradient buttons). Decline supported.
signal finished(result: Dictionary)

const SAM_MIN := 1
const SAM_MAX := 9

var _valence: int = -1
var _arousal: int = -1
var _title: String = "How do you feel right now?"
var _subtitle: String = "Tap a face for each row (research: valence and arousal)."

@onready var _body: VBoxContainer = $Margin/VBox


func _ready() -> void:
	_apply_style()
	_rebuild()


func configure(title: String, subtitle: String = "") -> void:
	_title = title
	if not subtitle.is_empty():
		_subtitle = subtitle
	if is_node_ready():
		_rebuild()


func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.1, 0.96)
	sb.border_color = Color(0.92, 0.82, 0.7, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	add_theme_stylebox_override("panel", sb)


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = _title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(1, 0.96, 0.92))
	_body.add_child(t)
	var st := Label.new()
	st.text = _subtitle
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 20)
	st.add_theme_color_override("font_color", Color(0.92, 0.88, 0.85))
	_body.add_child(st)
	_body.add_child(_make_sam_row("Valence (unpleasant → pleasant)", true))
	_body.add_child(_make_sam_row("Arousal (calm → activated)", false))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var decline := Button.new()
	decline.text = "Decline to answer"
	decline.custom_minimum_size = Vector2(280, 56)
	decline.pressed.connect(_on_decline)
	_style_btn(decline)
	row.add_child(decline)
	var ok := Button.new()
	ok.text = "Continue"
	ok.custom_minimum_size = Vector2(220, 56)
	ok.pressed.connect(_on_continue)
	_style_btn(ok)
	row.add_child(ok)
	_body.add_child(row)


func _make_sam_row(label_text: String, is_valence: bool) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var lb := Label.new()
	lb.text = label_text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 22)
	lb.add_theme_color_override("font_color", Color(1, 0.94, 0.88))
	vb.add_child(lb)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	for i in range(SAM_MIN, SAM_MAX + 1):
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(52, 52)
		b.tooltip_text = str(i)
		_style_sam_button(b, i, is_valence)
		var idx := i
		var for_valence := is_valence
		b.pressed.connect(func() -> void:
			if for_valence:
				_valence = idx
			else:
				_arousal = idx
		)
		hb.add_child(b)
	vb.add_child(hb)
	return vb


func _style_sam_button(b: Button, index: int, is_valence: bool) -> void:
	var t := float(index - SAM_MIN) / float(SAM_MAX - SAM_MIN)
	var col: Color
	if is_valence:
		col = Color(0.25 + 0.55 * t, 0.2 + 0.3 * t, 0.45 - 0.25 * t, 1.0)
	else:
		col = Color(0.2 + 0.6 * t, 0.25, 0.5 - 0.35 * t, 1.0)
	b.add_theme_color_override("font_color", Color(1, 0.98, 0.95))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = col.lightened(0.12)
	b.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = col.darkened(0.15)
	b.add_theme_stylebox_override("pressed", sb_p)


func _style_btn(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.92))


func _on_decline() -> void:
	finished.emit({"declined": true})


func _on_continue() -> void:
	if _valence < SAM_MIN or _arousal < SAM_MIN:
		return
	finished.emit({"declined": false, "valence": _valence, "arousal": _arousal})


func reset_values() -> void:
	_valence = -1
	_arousal = -1
