extends Control
## Fifteen-step grounding minigame (5 see → 1 taste). Resets if closed before completion.

signal finished

const TOTAL_STEPS := 15

const _CHEERS: Array[String] = [
	"You're doing beautifully — one sense at a time.",
	"Soft focus, sweet mind — you've got this.",
	"Each answer is a tiny sugar crystal of calm.",
	"Gentle as pulled sugar — keep going.",
	"Your attention is a gift you're giving yourself.",
	"Steady as cooling ganache — breathe and notice.",
	"That was brave. The next moment is yours too.",
	"You're gathering peace like collecting sprinkles.",
	"Warm and capable — stay with the noticing.",
	"Like tempering chocolate: patience, then shine.",
	"Every detail you name makes the room kinder.",
	"You're allowed to move slowly through this.",
	"Sweet clarity — you're anchoring in what is real.",
	"Your senses are allies; thank you for listening.",
	"Soft sparkle — that line landed perfectly.",
	"You're stirring calm into the moment.",
	"Like a perfect glaze — smooth and honest.",
	"That noticing counts more than you know.",
	"Keep the kindness you show the world for yourself too.",
	"You're mapping safety in ordinary things.",
	"Ribbon-candy resilience — flexible and bright.",
	"Cream-whipped courage — light and real.",
	"Marzipan-strong: small steps, solid ground.",
]

@onready var _header: Label = $RootVBox/Header
@onready var _instruction: Label = $RootVBox/Instruction
@onready var _cheer: Label = $RootVBox/CheerRow/CheerLabel
@onready var _input: LineEdit = $RootVBox/InputRow/LineEdit
@onready var _basin_scroll: ScrollContainer = $RootVBox/BasinScroll
@onready var _basin: VBoxContainer = $RootVBox/BasinScroll/BasinVBox
@onready var _anim_layer: Control = $AnimLayer

var _step: int = 0
var _last_cheer_i: int = -1
var _running: bool = false
var _submission_busy: bool = false
var _sampler_back_prev_focus: int = -1


func _ready() -> void:
	visible = false
	_cheer.modulate.a = 0.0
	_input.keep_editing_on_text_submit = true
	_input.placeholder_text = _placeholder_for_step(0)
	_header.text = "Sensory Sifting"
	_instruction.text = _instruction_for_step(0)
	_input.text_submitted.connect(_on_text_submitted)
	_configure_basin_scroll_focus()


func _configure_basin_scroll_focus() -> void:
	_basin_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	_basin_scroll.get_h_scroll_bar().focus_mode = Control.FOCUS_NONE


func run_sifting() -> void:
	_reset_state()
	_running = true
	visible = true
	_anim_layer.visible = true
	await get_tree().process_frame
	_mute_sampler_back_focus()
	_input.grab_focus()
	await finished
	_restore_sampler_back_focus()


func _reset_state() -> void:
	_submission_busy = false
	_step = 0
	_last_cheer_i = -1
	for c in _basin.get_children():
		c.queue_free()
	_input.clear()
	_input.placeholder_text = _placeholder_for_step(0)
	_instruction.text = _instruction_for_step(0)


func _unhandled_input(event: InputEvent) -> void:
	if not _running or not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_reset()


func quit_reset() -> void:
	_close_reset()


func _close_reset() -> void:
	if not _running:
		return
	_running = false
	_submission_busy = false
	_restore_sampler_back_focus()
	visible = false
	finished.emit()


func _sense_for_step(s: int) -> String:
	if s < 5:
		return "see"
	if s < 9:
		return "feel"
	if s < 12:
		return "hear"
	if s < 14:
		return "smell"
	return "taste"


func _placeholder_for_step(s: int) -> String:
	match _sense_for_step(s):
		"see":
			return "I see…"
		"feel":
			return "I feel…"
		"hear":
			return "I hear…"
		"smell":
			return "I smell…"
		_:
			return "I taste…"


func _instruction_for_step(s: int) -> String:
	var left: int = TOTAL_STEPS - s
	var sn: String = _sense_for_step(s).capitalize()
	return "%s — %d left. What is one thing you %s?" % [sn, left, _sense_for_step(s)]


func _on_text_submitted(t: String) -> void:
	if not _running or _submission_busy:
		return
	var trimmed: String = t.strip_edges()
	if trimmed.is_empty():
		_input.grab_focus()
		_input.call_deferred("grab_focus")
		return
	_submission_busy = true
	var sense: String = _sense_for_step(_step)
	var line: String = "I notice that I %s %s" % [sense, trimmed]
	_flash_cheer()
	await _animate_line_drop(line)
	_add_basin_line(line)
	_step += 1
	if _step >= TOTAL_STEPS:
		await _complete_sifting()
		_submission_busy = false
		return
	_input.clear()
	_input.placeholder_text = _placeholder_for_step(_step)
	_instruction.text = _instruction_for_step(_step)
	await get_tree().process_frame
	await _scroll_basin_bottom()
	await get_tree().process_frame
	_submission_busy = false
	await _refocus_line_edit_after_step()


func _mute_sampler_back_focus() -> void:
	var back: Control = get_node_or_null("../../BackButton") as Control
	if back == null:
		return
	_sampler_back_prev_focus = back.focus_mode
	back.focus_mode = Control.FOCUS_NONE


func _restore_sampler_back_focus() -> void:
	if _sampler_back_prev_focus < 0:
		return
	var back: Control = get_node_or_null("../../BackButton") as Control
	if back != null:
		back.focus_mode = _sampler_back_prev_focus
	_sampler_back_prev_focus = -1


func _refocus_line_edit_after_step() -> void:
	if not _running:
		return
	_input.grab_focus()
	await get_tree().process_frame
	_input.call_deferred("grab_focus")
	await get_tree().process_frame
	var owner: Control = get_viewport().gui_get_focus_owner() as Control
	if owner != _input:
		_input.grab_focus()
		await get_tree().process_frame
		owner = get_viewport().gui_get_focus_owner() as Control
		if owner != _input:
			_input.call_deferred("grab_focus")


func _pick_cheer() -> String:
	if _CHEERS.is_empty():
		return "Lovely."
	var i: int = randi() % _CHEERS.size()
	var guard: int = 0
	while i == _last_cheer_i and _CHEERS.size() > 1 and guard < 12:
		i = randi() % _CHEERS.size()
		guard += 1
	_last_cheer_i = i
	return _CHEERS[i]


func _flash_cheer() -> void:
	_cheer.text = _pick_cheer()
	_cheer.add_theme_color_override("font_color", Color(0.98, 0.88, 0.45, 1.0))
	_cheer.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.05, 1.0))
	_cheer.add_theme_constant_override("outline_size", 4)
	_cheer.scale = Vector2(0.8, 0.8)
	_cheer.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_cheer, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_cheer, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.9)
	tw.chain().tween_property(_cheer, "modulate:a", 0.0, 1.5)


func _animate_line_drop(text: String) -> void:
	var fly := Label.new()
	fly.focus_mode = Control.FOCUS_NONE
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.text = text
	fly.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fly.custom_minimum_size.x = _basin_scroll.size.x - 24.0
	fly.add_theme_font_size_override("font_size", 18)
	fly.add_theme_color_override("font_color", Color(0.95, 0.93, 1.0, 1.0))
	_anim_layer.add_child(fly)
	var g_in: Vector2 = _input.get_global_rect().position
	var g_b: Vector2 = _basin_scroll.get_global_rect().position + Vector2(12, _basin.size.y + 8)
	fly.global_position = g_in
	var tw := create_tween()
	tw.tween_property(fly, "global_position:y", g_b.y, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	fly.queue_free()


func _add_basin_line(text: String) -> void:
	var row := HBoxContainer.new()
	row.focus_mode = Control.FOCUS_NONE
	var lbl := Label.new()
	lbl.focus_mode = Control.FOCUS_NONE
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	var sh := ShaderMaterial.new()
	var sres := load("res://shaders/rainbow_shimmer.gdshader") as Shader
	if sres:
		sh.shader = sres
		lbl.material = sh
	row.add_child(lbl)
	_basin.add_child(row)


func _scroll_basin_bottom() -> void:
	await get_tree().process_frame
	var bar: ScrollBar = _basin_scroll.get_v_scroll_bar()
	bar.value = bar.max_value


func _complete_sifting() -> void:
	_restore_sampler_back_focus()
	_input.release_focus()
	CelestialVNState.set_panic_points_direct(0)
	CelestialVNState.set_panic_shield_direct(2)
	var big := Label.new()
	big.focus_mode = Control.FOCUS_NONE
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.text = "Sifted!"
	big.add_theme_font_size_override("font_size", 64)
	big.add_theme_color_override("font_color", Color(1, 0.92, 0.55, 1.0))
	big.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.25, 1.0))
	big.add_theme_constant_override("outline_size", 10)
	var sh2 := ShaderMaterial.new()
	var s2 := load("res://shaders/rainbow_shimmer.gdshader") as Shader
	if s2:
		sh2.shader = s2
		sh2.set_shader_parameter("rainbow_speed", 0.55)
		sh2.set_shader_parameter("shimmer", 0.75)
		big.material = sh2
	_anim_layer.add_child(big)
	big.global_position = get_viewport().get_visible_rect().get_center() - Vector2(120, 40)
	var tw := create_tween()
	tw.tween_property(big, "scale", Vector2(1.15, 1.15), 0.4).from(Vector2(0.6, 0.6))
	await tw.finished
	await get_tree().create_timer(1.4).timeout
	big.queue_free()
	_running = false
	visible = false
	finished.emit()
