extends CanvasLayer
## Blocking tutorial overlay: dim + text + optional flashing arrow toward a UI target. Click anywhere to dismiss.

@onready var _root: Control = $Root
@onready var _label: Label = $Root/Center/Panel/Margin/Label
@onready var _arrow: Label = $Root/Arrow

var _flash_tween: Tween
var _dismissed: bool = false


func _ready() -> void:
	visible = false
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.gui_input.connect(_on_root_gui_input)


func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dismissed = true


func show_heat_tutorial() -> void:
	await _run_tutorial(
		"Marzi's Heat level rises during stressful events... be sure to keep an eye on it.",
		"celestial_heat_meter"
	)


func show_sampler_arrow_tutorial() -> void:
	await _run_tutorial(
		"Click on Marzi's Sampler Box to help her manage her Heat.",
		"celestial_sampler_handle"
	)


func show_plain_tutorial(body: String) -> void:
	await _run_tutorial(body, "")


func _run_tutorial(body: String, arrow_group: String) -> void:
	_dismissed = false
	_label.text = body
	visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP

	if arrow_group.is_empty():
		_arrow.visible = false
		_kill_flash()
	else:
		_arrow.visible = true
		_arrow.text = "▼"
		_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_arrow.add_theme_font_size_override("font_size", 72)
		_arrow.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0, 1.0))
		_arrow.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.22, 1.0))
		_arrow.add_theme_constant_override("outline_size", 8)
		await get_tree().process_frame
		await get_tree().process_frame
		var target: Control = _first_control_in_group(arrow_group)
		if target == null:
			_arrow.visible = false
		else:
			var r: Rect2 = target.get_global_rect()
			var cx: float = r.position.x + r.size.x * 0.5
			var ay: float = r.position.y - 72.0
			_arrow.reset_size()
			var sz: Vector2 = _arrow.get_combined_minimum_size()
			_arrow.position = Vector2(cx - sz.x * 0.5, ay)
			_start_arrow_flash()

	while not _dismissed:
		await get_tree().process_frame

	_kill_flash()
	_arrow.visible = false
	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _first_control_in_group(group_name: String) -> Control:
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for n in nodes:
		if n is Control:
			return n as Control
	return null


func _start_arrow_flash() -> void:
	_kill_flash()
	if GameSaveManager.is_reduce_motion_enabled():
		if _arrow:
			_arrow.modulate.a = 1.0
		return
	_flash_tween = create_tween()
	_flash_tween.set_loops()
	_flash_tween.tween_property(_arrow, "modulate:a", 0.35, 0.38)
	_flash_tween.tween_property(_arrow, "modulate:a", 1.0, 0.38)


func _kill_flash() -> void:
	if _flash_tween != null and is_instance_valid(_flash_tween):
		_flash_tween.kill()
	_flash_tween = null
	if _arrow:
		_arrow.modulate.a = 1.0
