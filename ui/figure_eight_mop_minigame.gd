extends CanvasLayer
## Full-screen trace minigame: hold LMB and follow the infinity path Work → Rest → Play.

signal finished

const PATH_SAMPLES := 360
const TRACE_TOLERANCE := 64.0
const COVERAGE_FRAC := 0.88

var _path_local: PackedVector2Array = PackedVector2Array()
var _draw_center: Vector2 = Vector2.ZERO
var _draw_size: Vector2 = Vector2(1440, 800)

@onready var _area: Control = $Center/DrawArea
@onready var _path_line: Line2D = $Center/DrawArea/PathLine
@onready var _trail: Line2D = $Center/DrawArea/TrailLine
@onready var _label_work: Label = $Center/DrawArea/LabelWork
@onready var _label_rest: Label = $Center/DrawArea/LabelRest
@onready var _label_play: Label = $Center/DrawArea/LabelPlay
@onready var _instr: Label = $Center/DrawArea/Instructions
@onready var _spotless: Label = $Center/DrawArea/SpotlessLabel
@onready var _input_catcher: Control = $InputCatcher

var _instruction_override: String = ""

var _drawing: bool = false
var _covered: PackedByteArray = PackedByteArray()


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spotless.visible = false
	_apply_instruction_text()
	if _area:
		_area.custom_minimum_size = _draw_size
	_build_path()
	_path_line.points = _path_local
	_trail.clear_points()
	_trail.width = 20.0
	_trail.default_color = Color(0.35, 0.55, 0.95, 0.85)
	_path_line.width = 8.0
	_path_line.default_color = Color(0.55, 0.55, 0.62, 0.9)
	_path_line.z_index = 0
	_trail.z_index = 1
	_covered.resize(PATH_SAMPLES)
	for i in PATH_SAMPLES:
		_covered[i] = 0
	_input_catcher.gui_input.connect(_on_input_catcher_gui_input)


func set_instruction_override(text: String) -> void:
	_instruction_override = text
	if is_node_ready() and _instr:
		_apply_instruction_text()


func _apply_instruction_text() -> void:
	if _instr == null:
		return
	if _instruction_override.strip_edges().is_empty():
		_instr.text = "Hold left mouse and trace the loop from Work → Rest → Play without lifting."
	else:
		_instr.text = _instruction_override


func _build_path() -> void:
	_path_local.clear()
	var half := _draw_size * 0.5
	_draw_center = half
	for i in PATH_SAMPLES:
		var t := TAU * float(i) / float(PATH_SAMPLES)
		var x := sin(t) * 1.0
		var y := sin(t) * cos(t) * 1.0
		var p := Vector2(x, y) * minf(half.x * 0.82, half.y * 0.92)
		_path_local.append(p + half)
	_place_labels()


func _place_labels() -> void:
	if _path_local.size() < 8:
		return
	var i_work := 0
	var i_play := 0
	var best_w := 999999.0
	var best_p := -999999.0
	var center := _draw_center
	for i in _path_local.size():
		var p := _path_local[i]
		var score_w := p.x + p.y
		if score_w < best_w:
			best_w = score_w
			i_work = i
		var score_p := p.x - p.y
		if score_p > best_p:
			best_p = score_p
			i_play = i
	var i_rest := 0
	var best_r := 999999.0
	for i in _path_local.size():
		var d := _path_local[i].distance_to(center)
		if d < best_r:
			best_r = d
			i_rest = i
	_label_work.text = "work"
	_label_rest.text = "rest"
	_label_play.text = "play"
	_label_work.position = _path_local[i_work] + Vector2(-72, -56)
	_label_rest.position = _path_local[i_rest] + Vector2(-44, -28)
	_label_play.position = _path_local[i_play] + Vector2(-56, 96)
	for lbl in [_label_work, _label_rest, _label_play]:
		lbl.z_index = 2
		lbl.add_theme_font_size_override("font_size", 44)
	if _instr:
		_instr.z_index = 2
		_instr.add_theme_font_size_override("font_size", 36)
	_spotless.z_index = 3


func _on_input_catcher_gui_input(event: InputEvent) -> void:
	if _spotless.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drawing = true
				_trail.clear_points()
				for i in PATH_SAMPLES:
					_covered[i] = 0
			else:
				_drawing = false
				_try_complete()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drawing:
		var local := _area.get_local_mouse_position()
		_trail.add_point(local)
		_update_coverage(local)
		get_viewport().set_input_as_handled()


func _nearest_path_index(local: Vector2) -> int:
	var best_i := 0
	var best_d := 999999.0
	for i in _path_local.size():
		var d := local.distance_to(_path_local[i])
		if d < best_d:
			best_d = d
			best_i = i
	return best_i


func _update_coverage(local: Vector2) -> void:
	var nearest := _nearest_path_index(local)
	if local.distance_to(_path_local[nearest]) > TRACE_TOLERANCE:
		return
	var lo := maxi(0, nearest - 4)
	var hi := mini(PATH_SAMPLES - 1, nearest + 4)
	for i in range(lo, hi + 1):
		if local.distance_to(_path_local[i]) <= TRACE_TOLERANCE:
			_covered[i] = 1

func _coverage_ratio() -> float:
	var n := 0
	for i in PATH_SAMPLES:
		if _covered[i] != 0:
			n += 1
	return float(n) / float(PATH_SAMPLES)


func _try_complete() -> void:
	if _coverage_ratio() >= COVERAGE_FRAC:
		_run_success()
	else:
		_trail.clear_points()


func _run_success() -> void:
	_spotless.visible = true
	_spotless.text = "Spotless!"
	_spotless.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_spotless, "modulate:a", 1.0, 0.35)
	_trail.default_color = Color(0.55, 0.85, 1.0, 1.0)
	tw.tween_property(_trail, "width", 28.0, 0.25)
	tw.chain().tween_interval(0.55)
	tw.tween_callback(_finish_and_exit)


func _finish_and_exit() -> void:
	finished.emit()
	queue_free()
