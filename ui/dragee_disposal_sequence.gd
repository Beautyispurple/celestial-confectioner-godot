extends CanvasLayer
## Gather dragees into dustpan → tilt dustpan → release into trash.

const _LAYER := 94

@onready var _host: Control = $Host

var _user_abort: bool = false


func _ready() -> void:
	layer = _LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_user_abort = true
		get_viewport().set_input_as_handled()


func run_sequence(thought_display: String) -> bool:
	_user_abort = false
	visible = true
	for c in _host.get_children():
		c.queue_free()
	await get_tree().process_frame

	if not await _phase_gather(thought_display):
		visible = false
		return false
	if not await _phase_tilt(thought_display):
		visible = false
		return false
	if not await _phase_trash():
		visible = false
		return false
	visible = false
	return true


## Click each scattered dragee to sweep it into the dustpan (replaces closet figure-eight here).
func _phase_gather(thought_snip: String) -> bool:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(center)
	var wrap := MarginContainer.new()
	center.add_child(wrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	wrap.add_child(v)

	var title := Label.new()
	title.text = "Sweep every dragee that carries your thought into the dustpan."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(440, 0)
	v.add_child(title)

	var thought_lbl := Label.new()
	var snip := thought_snip.strip_edges()
	if snip.length() > 72:
		snip = snip.substr(0, 69) + "…"
	thought_lbl.text = "“%s”" % snip if not snip.is_empty() else "…"
	thought_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thought_lbl.custom_minimum_size = Vector2(440, 0)
	thought_lbl.add_theme_font_size_override("font_size", 15)
	thought_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.95, 1.0))
	v.add_child(thought_lbl)

	var scatter := Control.new()
	scatter.custom_minimum_size = Vector2(480, 220)
	scatter.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(scatter)

	var pan_row := HBoxContainer.new()
	pan_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(pan_row)
	var pan := PanelContainer.new()
	pan.custom_minimum_size = Vector2(260, 52)
	var pan_inner := MarginContainer.new()
	pan_inner.add_theme_constant_override("margin_top", 8)
	pan_inner.add_theme_constant_override("margin_bottom", 8)
	pan.add_child(pan_inner)
	var pan_lbl := Label.new()
	pan_lbl.text = "Dustpan"
	pan_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pan_inner.add_child(pan_lbl)
	pan_row.add_child(pan)

	const TOTAL := 6
	var gathered := {"n": 0}
	var st := {"done": false}

	var positions: Array[Vector2] = [
		Vector2(32, 24), Vector2(140, 60), Vector2(260, 28), Vector2(360, 80),
		Vector2(80, 120), Vector2(220, 150),
	]
	for i in range(TOTAL):
		var b := Button.new()
		b.text = "★"
		b.custom_minimum_size = Vector2(44, 44)
		b.position = positions[i] if i < positions.size() else Vector2(50 + i * 55, 40)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var bb: Button = b
		b.pressed.connect(
			func() -> void:
				if bb.disabled:
					return
				bb.disabled = true
				bb.modulate = Color(1, 1, 1, 0.25)
				gathered["n"] = int(gathered["n"]) + 1
				if int(gathered["n"]) >= TOTAL:
					st["done"] = true
		)
		scatter.add_child(b)

	while not st["done"] and not _user_abort:
		await get_tree().process_frame
	center.queue_free()
	if _user_abort:
		return false
	return true


func _phase_tilt(_thought: String) -> bool:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(center)
	var wrap := MarginContainer.new()
	center.add_child(wrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	wrap.add_child(v)
	var lbl := Label.new()
	lbl.text = "Tilt the dustpan — drag the slider until the dragees slide toward the trash."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(400, 0)
	v.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 0.0
	slider.custom_minimum_size = Vector2(400, 28)
	v.add_child(slider)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var btn := Button.new()
	btn.text = "Ready to empty"
	btn.disabled = true
	row.add_child(btn)

	var st := {"done": false, "ok": false}
	slider.value_changed.connect(
		func(x: float) -> void:
			btn.disabled = x < 88.0
	)
	btn.pressed.connect(
		func() -> void:
			if btn.disabled:
				return
			st["ok"] = true
			st["done"] = true
	)

	while not st["done"] and not _user_abort:
		await get_tree().process_frame
	center.queue_free()
	if _user_abort:
		return false
	return bool(st["ok"])


func _phase_trash() -> bool:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(center)
	var wrap := MarginContainer.new()
	center.add_child(wrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	wrap.add_child(v)
	var lbl := Label.new()
	lbl.text = "Let it go — drop the bundle into the trash."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
	var btn := Button.new()
	btn.text = "Release into the trash"
	btn.custom_minimum_size = Vector2(280, 44)
	v.add_child(btn)

	var st := {"done": false, "ok": false}
	btn.pressed.connect(
		func() -> void:
			st["ok"] = true
			st["done"] = true
	)

	while not st["done"] and not _user_abort:
		await get_tree().process_frame
	center.queue_free()
	if _user_abort:
		return false
	return bool(st["ok"])
