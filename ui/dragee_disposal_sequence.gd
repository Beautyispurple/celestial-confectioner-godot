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
	if not await _phase_trash(thought_display):
		visible = false
		return false
	visible = false
	return true


const _CHIP_SCENE := preload("res://ui/dragee_thought_chip.tscn")


## Drag each scattered dragee onto the dustpan.
func _phase_gather(thought_snip: String) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var game_w: float = vp.x * 0.75
	var game_h: float = vp.y * 0.75
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(center)
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 8)
	wrap.add_theme_constant_override("margin_right", 8)
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 8)
	wrap.custom_minimum_size = Vector2(game_w, game_h)
	center.add_child(wrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", maxi(14, int(vp.y * 0.018)))
	wrap.add_child(v)

	var title := Label.new()
	title.text = "Click and hold a dragee, drag it onto the dustpan, then release the mouse to drop it in. Gather every dragee."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(game_w - 24.0, 0.0)
	title.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.028), 18, 28))
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.98, 1.0))
	v.add_child(title)

	var thought_lbl := Label.new()
	var snip_full := thought_snip.strip_edges()
	var snip := snip_full
	if snip.length() > 120:
		snip = snip.substr(0, 117) + "…"
	thought_lbl.text = "“%s”" % snip if not snip.is_empty() else "…"
	thought_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thought_lbl.custom_minimum_size = Vector2(game_w - 24.0, 0.0)
	thought_lbl.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.024), 16, 24))
	thought_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.95, 1.0))
	v.add_child(thought_lbl)

	var stack := Control.new()
	var stack_h: float = maxf(vp.y * 0.36, game_h * 0.5)
	var stack_w: float = maxf(320.0, game_w - 40.0)
	stack.custom_minimum_size = Vector2(stack_w, stack_h)
	v.add_child(stack)

	var scatter := Control.new()
	scatter.set_anchors_preset(Control.PRESET_FULL_RECT)
	scatter.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_child(scatter)

	var drag_overlay := Control.new()
	drag_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_overlay.z_index = 10
	stack.add_child(drag_overlay)

	var pan_row := HBoxContainer.new()
	pan_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(pan_row)

	var chip_sz: float = maxf(144.0, minf(stack_w, stack_h) * 0.28)
	var pan_w: float = maxf(game_w * 0.55, chip_sz * 3.2)
	var pan_h: float = maxf(88.0, chip_sz * 0.62)
	var pan_hit := PanelContainer.new()
	pan_hit.custom_minimum_size = Vector2(pan_w, pan_h)
	pan_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	var pan_sb := StyleBoxFlat.new()
	pan_sb.bg_color = Color(0.22, 0.18, 0.28, 1.0)
	pan_sb.border_color = Color(0.75, 0.65, 0.88, 0.65)
	pan_sb.set_border_width_all(maxi(3, int(chip_sz / 28.0)))
	pan_sb.set_corner_radius_all(maxi(12, int(chip_sz / 10.0)))
	pan_hit.add_theme_stylebox_override("panel", pan_sb)
	pan_row.add_child(pan_hit)

	var pan_inner := HBoxContainer.new()
	pan_inner.add_theme_constant_override("separation", maxi(12, int(chip_sz / 8.0)))
	pan_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	pan_hit.add_child(pan_inner)

	var pan_icon := Label.new()
	pan_icon.text = "🧹"
	pan_icon.add_theme_font_size_override("font_size", clampi(int(chip_sz * 0.42), 40, 72))
	pan_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pan_inner.add_child(pan_icon)

	var pan_lbl := Label.new()
	pan_lbl.text = "Dustpan — release here"
	pan_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pan_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pan_lbl.add_theme_font_size_override("font_size", clampi(int(chip_sz * 0.2), 18, 30))
	pan_inner.add_child(pan_lbl)

	const TOTAL := 6
	var gathered := {"n": 0}
	var st := {"done": false}

	var pos_fracs: Array[Vector2] = [
		Vector2(0.04, 0.06),
		Vector2(0.38, 0.1),
		Vector2(0.68, 0.05),
		Vector2(0.52, 0.38),
		Vector2(0.12, 0.48),
		Vector2(0.28, 0.72),
	]
	var chip_body: String = snip_full if not snip_full.is_empty() else "…"
	if chip_body.length() > 100:
		chip_body = chip_body.substr(0, 97) + "…"
	var drop_pad: float = maxf(28.0, chip_sz * 0.22)

	for i in range(TOTAL):
		var chip: DrageeThoughtChip = _CHIP_SCENE.instantiate() as DrageeThoughtChip
		scatter.add_child(chip)
		chip.custom_minimum_size = Vector2(chip_sz, chip_sz)
		chip.draggable = true
		var pfrac: Vector2 = pos_fracs[i] if i < pos_fracs.size() else Vector2(0.08 + 0.11 * float(i), 0.2)
		var px: float = pfrac.x * maxf(4.0, stack_w - chip_sz)
		var py: float = pfrac.y * maxf(4.0, stack_h - chip_sz)
		chip.position = Vector2(px, py)
		chip.set_thought_text(chip_body)
		chip.z_index = 0
		chip.remember_scatter_slot(scatter, chip.position)

		var c: DrageeThoughtChip = chip
		chip.drag_started.connect(
			func() -> void:
				if c.disabled:
					return
				c.z_index = 24
				c.reparent_for_drag(drag_overlay)
		)
		chip.drag_ended.connect(
			func(gp: Vector2) -> void:
				if c.disabled:
					return
				var rect: Rect2 = pan_hit.get_global_rect().grow(drop_pad)
				if rect.has_point(gp):
					c.disabled = true
					c.mouse_filter = Control.MOUSE_FILTER_IGNORE
					c.modulate = Color(1, 1, 1, 0.25)
					gathered["n"] = int(gathered["n"]) + 1
					if int(gathered["n"]) >= TOTAL:
						st["done"] = true
				else:
					c.z_index = 0
					c.restore_scatter_slot()
		)

	while not st["done"] and not _user_abort:
		await get_tree().process_frame
	center.queue_free()
	if _user_abort:
		return false
	return true


func _phase_tilt(_thought: String) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var game_w: float = vp.x * 0.75
	var game_h: float = vp.y * 0.75
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(center)
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 8)
	wrap.add_theme_constant_override("margin_right", 8)
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 8)
	wrap.custom_minimum_size = Vector2(game_w, game_h)
	center.add_child(wrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", maxi(14, int(vp.y * 0.018)))
	wrap.add_child(v)

	var lbl := Label.new()
	lbl.text = "Tilt the dustpan — drag the slider until the dragees slide toward the trash."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(game_w - 24.0, 0.0)
	lbl.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.028), 18, 32))
	lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.98, 1.0))
	v.add_child(lbl)

	var snip_full := _thought.strip_edges()
	if not snip_full.is_empty():
		var snip := snip_full
		if snip.length() > 120:
			snip = snip.substr(0, 117) + "…"
		var thought_lbl := Label.new()
		thought_lbl.text = "“%s”" % snip
		thought_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		thought_lbl.custom_minimum_size = Vector2(game_w - 24.0, 0.0)
		thought_lbl.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.024), 16, 28))
		thought_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.95, 1.0))
		v.add_child(thought_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 0.0
	slider.custom_minimum_size = Vector2(maxf(320.0, game_w - 40.0), maxf(28.0, vp.y * 0.038))
	v.add_child(slider)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var btn := Button.new()
	btn.text = "Ready to empty"
	btn.disabled = true
	btn.custom_minimum_size = Vector2(maxf(200.0, game_w * 0.28), maxf(40.0, vp.y * 0.052))
	btn.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.022), 16, 26))
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


func _phase_trash(thought_display: String) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var game_w: float = vp.x * 0.75
	var game_h: float = vp.y * 0.75
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(center)
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 8)
	wrap.add_theme_constant_override("margin_right", 8)
	wrap.add_theme_constant_override("margin_top", 8)
	wrap.add_theme_constant_override("margin_bottom", 8)
	wrap.custom_minimum_size = Vector2(game_w, game_h)
	center.add_child(wrap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", maxi(14, int(vp.y * 0.016)))
	wrap.add_child(v)

	var lbl := Label.new()
	lbl.text = "Let it go — drag the purple chip down into the trash."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(game_w - 24.0, 0.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.028), 20, 34))
	lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.98, 1.0))
	v.add_child(lbl)

	var zone := Control.new()
	var zone_w: float = maxf(320.0, game_w - 32.0)
	var zone_h: float = maxf(vp.y * 0.42, game_h * 0.62)
	zone.custom_minimum_size = Vector2(zone_w, zone_h)
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone.mouse_filter = Control.MOUSE_FILTER_PASS
	zone.clip_contents = false
	v.add_child(zone)

	var trash_fill := ColorRect.new()
	trash_fill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	trash_fill.anchor_top = 0.62
	trash_fill.color = Color(0.1, 0.08, 0.14, 1.0)
	trash_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(trash_fill)

	var trash_caption := Label.new()
	trash_caption.text = "Trash"
	trash_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trash_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trash_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	trash_caption.anchor_top = 0.62
	trash_caption.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.026), 18, 36))
	trash_caption.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85, 1.0))
	trash_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(trash_caption)

	var drag_overlay := Control.new()
	drag_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_overlay.z_index = 10
	zone.add_child(drag_overlay)

	var chip_body: String = thought_display.strip_edges()
	if chip_body.is_empty():
		chip_body = "…"
	elif chip_body.length() > 200:
		chip_body = chip_body.substr(0, 197) + "…"

	var chip_w: float = maxf(zone_w * 0.82, minf(game_w * 0.88, 720.0))
	var chip_h: float = maxf(maxf(vp.y * 0.14, zone_h * 0.22), 112.0)

	var chip: DrageeThoughtChip = _CHIP_SCENE.instantiate() as DrageeThoughtChip
	zone.add_child(chip)
	chip.draggable = true
	chip.custom_minimum_size = Vector2(chip_w, chip_h)
	chip.set_draggable_font_range(0.22, 20, 72)
	chip.set_thought_text(chip_body)
	chip.z_index = 2

	await get_tree().process_frame
	var start_x: float = maxf(8.0, (zone_w - chip_w) * 0.5)
	var start_y: float = maxf(10.0, zone_h * 0.05)
	chip.position = Vector2(start_x, start_y)
	chip.remember_scatter_slot(zone, chip.position)

	var drop_pad: float = maxf(24.0, vp.y * 0.02)
	var st := {"done": false, "ok": false}
	var c: DrageeThoughtChip = chip
	chip.drag_started.connect(
		func() -> void:
			if c.disabled:
				return
			c.z_index = 24
			c.reparent_for_drag(drag_overlay)
	)
	chip.drag_ended.connect(
		func(gp: Vector2) -> void:
			if c.disabled:
				return
			var rect: Rect2 = trash_fill.get_global_rect().grow(drop_pad)
			if rect.has_point(gp):
				c.disabled = true
				c.mouse_filter = Control.MOUSE_FILTER_IGNORE
				c.modulate = Color(1, 1, 1, 0.2)
				st["ok"] = true
				st["done"] = true
			else:
				c.z_index = 2
				c.restore_scatter_slot()
	)

	while not st["done"] and not _user_abort:
		await get_tree().process_frame
	center.queue_free()
	if _user_abort:
		return false
	return bool(st["ok"])
