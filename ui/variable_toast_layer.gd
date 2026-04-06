extends CanvasLayer
## Sequential floating toasts: fade in, 2s hold, fade out. Placed just above the Dialogic textbox; ignores mouse.

const FADE_IN := 0.35
const HOLD := 2.0
const FADE_OUT := 0.45
const GAP_ABOVE_TEXTBOX := 10.0
const FALLBACK_BOTTOM_OFFSET := 220.0

@onready var _anchor: Control = $ToastAnchor
@onready var _label: Label = $ToastAnchor/ToastLabel


func _ready() -> void:
	layer = 128
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_anchor.modulate.a = 0.0
	_label.text = ""


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


func _position_label() -> void:
	await get_tree().process_frame
	var ms: Vector2 = _label.get_minimum_size()
	var panel := _get_textbox_panel()
	if panel != null and is_instance_valid(panel) and panel.is_visible_in_tree():
		var gr: Rect2 = panel.get_global_rect()
		_label.position = Vector2(
			gr.position.x + (gr.size.x - ms.x) * 0.5,
			gr.position.y - ms.y - GAP_ABOVE_TEXTBOX
		)
	else:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		_label.position = Vector2((vp.x - ms.x) * 0.5, vp.y - FALLBACK_BOTTOM_OFFSET - ms.y)


func show_toast(display_label: String, signed_delta: int) -> void:
	var sign_str := "+" if signed_delta > 0 else ""
	_label.text = "%s %s%d" % [display_label, sign_str, signed_delta]
	if display_label == "Heat" or display_label == "Social Battery":
		if signed_delta < 0:
			_label.add_theme_color_override("font_color", Color(0.35, 0.82, 0.42, 1.0))
		elif signed_delta > 0:
			_label.add_theme_color_override("font_color", Color(0.92, 0.22, 0.22, 1.0))
		else:
			_label.remove_theme_color_override("font_color")
	else:
		_label.remove_theme_color_override("font_color")
	_anchor.modulate.a = 0.0
	await _position_label()
	var tw := create_tween()
	tw.tween_property(_anchor, "modulate:a", 1.0, FADE_IN)
	await tw.finished
	await get_tree().create_timer(HOLD).timeout
	var tw2 := create_tween()
	tw2.tween_property(_anchor, "modulate:a", 0.0, FADE_OUT)
	await tw2.finished
	_label.text = ""
