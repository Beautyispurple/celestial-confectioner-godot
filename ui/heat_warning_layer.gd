extends CanvasLayer
## Heat guidance above Dialogic textbox: orange tier intermittent, red tier always on.

const ORANGE_GAP_SEC := 3.0
const ORANGE_SHOW_SEC := 4.16
const ORANGE_SWAP_SENTENCE_SEC := 2.08
const GAP_ABOVE_TEXTBOX := 10.0
const FALLBACK_BOTTOM_OFFSET := 280.0

const MSG_ORANGE_1 := "I need to turn the heat down soon, otherwise I'll melt."
const MSG_ORANGE_2 := "Do I have something in my sampler box that will help?"
const MSG_RED_1 := "I need to turn the heat down NOW or I can't function."
const MSG_RED_2 := "Is there something in my sampler box that will help?"

@onready var _anchor: Control = $WarningAnchor
@onready var _strip: CenterContainer = $WarningAnchor/CenterStrip
@onready var _label: Label = $WarningAnchor/CenterStrip/WarningLabel

var _orange_timer: float = 0.0
var _orange_next_flip: float = ORANGE_GAP_SEC
var _orange_showing: bool = false
var _orange_sentence_timer: float = 0.0
var _orange_sentence_alt: bool = false
var _red_sentence_alt: bool = false
var _red_swap_timer: float = 0.0


func _ready() -> void:
	layer = 126
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_anchor.visible = false
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	# Orange + red guidance only; layer 126 sits above the sampler — never intercept clicks.
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 31)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.12, 1.0))
	_label.add_theme_constant_override("outline_size", 7)
	# Stable LTR line layout (Control.TextDirection, not TextServer.Direction).
	_label.text_direction = Control.TEXT_DIRECTION_LTR
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	CelestialVNState.panic_tier_changed.connect(_on_tier_changed)
	_apply_tier_state()


func _process(delta: float) -> void:
	var tier: int = CelestialVNState.get_panic_tier()
	if tier == CelestialVNState.PanicTier.CRISIS:
		_red_swap_timer += delta
		if _red_swap_timer >= ORANGE_SWAP_SENTENCE_SEC:
			_red_swap_timer = 0.0
			_red_sentence_alt = not _red_sentence_alt
			_label.text = MSG_RED_2 if _red_sentence_alt else MSG_RED_1
			_show_positioned()
		return
	if tier != CelestialVNState.PanicTier.LOCK_RATIONAL:
		return
	_orange_timer += delta
	if _orange_showing:
		_orange_sentence_timer += delta
		if _orange_sentence_timer >= ORANGE_SWAP_SENTENCE_SEC:
			_orange_sentence_timer = 0.0
			_orange_sentence_alt = not _orange_sentence_alt
			_label.text = MSG_ORANGE_2 if _orange_sentence_alt else MSG_ORANGE_1
			_show_positioned()
		if _orange_timer >= ORANGE_SHOW_SEC:
			_orange_showing = false
			_orange_timer = 0.0
			_orange_next_flip = ORANGE_GAP_SEC
			_orange_sentence_timer = 0.0
			_anchor.visible = false
	else:
		if _orange_timer >= _orange_next_flip:
			_orange_showing = true
			_orange_timer = 0.0
			_orange_sentence_timer = 0.0
			_orange_sentence_alt = false
			_label.text = MSG_ORANGE_1
			_show_positioned()


func _on_tier_changed(_t: int) -> void:
	_apply_tier_state()


func _apply_tier_state() -> void:
	var tier: int = CelestialVNState.get_panic_tier()
	_orange_timer = 0.0
	_orange_showing = false
	_orange_next_flip = ORANGE_GAP_SEC
	_orange_sentence_timer = 0.0
	_orange_sentence_alt = false
	_red_swap_timer = 0.0
	_red_sentence_alt = false
	if tier == CelestialVNState.PanicTier.CRISIS:
		_label.text = MSG_RED_1
		_show_positioned()
	elif tier == CelestialVNState.PanicTier.LOCK_RATIONAL:
		_anchor.visible = false
	else:
		_anchor.visible = false


func _show_positioned() -> void:
	_anchor.visible = true
	call_deferred("_deferred_position")


func _on_viewport_size_changed() -> void:
	if not _anchor.visible:
		return
	call_deferred("_deferred_position")


func _deferred_position() -> void:
	await get_tree().process_frame
	var panel := _get_textbox_panel()
	var vp_rect: Rect2 = get_viewport().get_visible_rect()
	# CanvasLayer has no Control size — pin WarningAnchor to the visible viewport.
	# layout_mode: 0 = position (Control.LayoutMode constants are not exposed to GDScript).
	_anchor.set("layout_mode", 0)
	_anchor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_anchor.position = vp_rect.position
	_anchor.size = vp_rect.size
	var max_w: float = minf(720.0, maxf(120.0, vp_rect.size.x - 48.0))
	_label.custom_minimum_size = Vector2(max_w, 0.0)
	await get_tree().process_frame
	var ms: Vector2 = _label.get_minimum_size()
	var top_y_local: float
	if panel != null and is_instance_valid(panel) and panel.is_visible_in_tree():
		var gr: Rect2 = panel.get_global_rect()
		top_y_local = gr.position.y - vp_rect.position.y - ms.y - GAP_ABOVE_TEXTBOX
	else:
		top_y_local = vp_rect.size.y - FALLBACK_BOTTOM_OFFSET - ms.y
	# Full-width strip; CenterContainer centers the label block horizontally (and vertically in the strip).
	_strip.set("layout_mode", 0)
	_strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_strip.position = Vector2(0.0, top_y_local)
	_strip.size = Vector2(_anchor.size.x, maxf(ms.y, 1.0))


func _get_textbox_panel() -> Control:
	if not is_instance_valid(Dialogic):
		return null
	var styles = Dialogic.Styles
	if styles == null or not styles.has_active_layout_node():
		return null
	var dt: Node = styles.get_first_node_in_layout("dialogic_dialog_text")
	if dt == null:
		return null
	var root: Variant = dt.get("textbox_root")
	if root is Control:
		return root as Control
	return null
