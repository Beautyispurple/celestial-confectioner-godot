extends CanvasLayer
## Heat guidance above Dialogic textbox: orange tier intermittent, red tier always on.

const ORANGE_MIN_SEC := 5.0
const ORANGE_MAX_SEC := 9.0
const ORANGE_SHOW_SEC := 3.2
const GAP_ABOVE_TEXTBOX := 10.0
const FALLBACK_BOTTOM_OFFSET := 280.0

const MSG_ORANGE := "I need to turn the heat down soon, otherwise I'll melt... do I have something in my sampler box that will help?"
const MSG_RED := "I need to turn the heat down NOW or I can't function...is there something in my sampler box that will help?"

@onready var _anchor: Control = $WarningAnchor
@onready var _label: Label = $WarningAnchor/WarningLabel

var _orange_timer: float = 0.0
var _orange_next_flip: float = 3.0
var _orange_showing: bool = false


func _ready() -> void:
	layer = 126
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_anchor.visible = false
	# Orange + red guidance only; layer 126 sits above the sampler — never intercept clicks.
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.12, 1.0))
	_label.add_theme_constant_override("outline_size", 7)
	CelestialVNState.panic_tier_changed.connect(_on_tier_changed)
	_apply_tier_state()


func _process(delta: float) -> void:
	var tier: int = CelestialVNState.get_panic_tier()
	if tier != CelestialVNState.PanicTier.LOCK_RATIONAL:
		return
	_orange_timer += delta
	if _orange_showing:
		if _orange_timer >= ORANGE_SHOW_SEC:
			_orange_showing = false
			_orange_timer = 0.0
			_orange_next_flip = randf_range(ORANGE_MIN_SEC, ORANGE_MAX_SEC)
			_anchor.visible = false
	else:
		if _orange_timer >= _orange_next_flip:
			_orange_showing = true
			_orange_timer = 0.0
			_label.text = MSG_ORANGE
			_show_positioned()


func _on_tier_changed(_t: int) -> void:
	_apply_tier_state()


func _apply_tier_state() -> void:
	var tier: int = CelestialVNState.get_panic_tier()
	_orange_timer = 0.0
	_orange_showing = false
	_orange_next_flip = randf_range(ORANGE_MIN_SEC, ORANGE_MAX_SEC)
	if tier == CelestialVNState.PanicTier.CRISIS:
		_label.text = MSG_RED
		_show_positioned()
	elif tier == CelestialVNState.PanicTier.LOCK_RATIONAL:
		_anchor.visible = false
	else:
		_anchor.visible = false


func _show_positioned() -> void:
	_anchor.visible = true
	call_deferred("_deferred_position")


func _deferred_position() -> void:
	await get_tree().process_frame
	var panel := _get_textbox_panel()
	var max_w: float = 720.0
	_label.custom_minimum_size = Vector2(minf(max_w, get_viewport().get_visible_rect().size.x - 48.0), 0.0)
	var ms: Vector2 = _label.get_minimum_size()
	if panel != null and is_instance_valid(panel) and panel.is_visible_in_tree():
		var gr: Rect2 = panel.get_global_rect()
		_label.position = Vector2(
			gr.position.x + (gr.size.x - ms.x) * 0.5,
			gr.position.y - ms.y - GAP_ABOVE_TEXTBOX
		)
	else:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_label.position = Vector2((vp.x - ms.x) * 0.5, vp.y - FALLBACK_BOTTOM_OFFSET - ms.y)


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
