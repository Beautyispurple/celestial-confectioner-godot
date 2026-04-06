class_name BreathingSugarOrb
extends Control
## Molten sugar / crystal / glass sphere drawn in confectionery palette.

var sphere_radius: float = 88.0
var crystal_strength: float = 0.0
var shell_alpha: float = 0.0
var molten_warmth: float = 1.0
var hover_offset: Vector2 = Vector2.ZERO


func _draw() -> void:
	var c: Vector2 = size * 0.5
	c += hover_offset
	var r: float = sphere_radius
	# Soft outer bloom (rose-gold mist)
	for i in range(5):
		var a: float = 0.035 - i * 0.005
		draw_circle(c, r + float(i) * 14.0, Color(1.0, 0.82, 0.92, a))
	# Molten body — amber / spun sugar
	var body := Color(1.0, 0.72 + 0.12 * molten_warmth, 0.48 + 0.1 * molten_warmth, 0.42)
	draw_circle(c, r, body)
	draw_circle(c, r * 0.72, Color(1.0, 0.55, 0.38, 0.38))
	draw_circle(c, r * 0.38, Color(1.0, 0.92, 0.78, 0.55))
	# Crystalline spokes (first hold)
	if crystal_strength > 0.001:
		var spoke_col := Color(0.95, 0.88, 1.0, crystal_strength * 0.55)
		for k in 18:
			var ang: float = float(k) * TAU / 18.0
			var outer: Vector2 = c + Vector2.from_angle(ang) * r * 0.98
			draw_line(c + Vector2.from_angle(ang) * r * 0.22, outer, spoke_col, 1.4, true)
		for k in 9:
			var ang2: float = float(k) * TAU / 9.0 + 0.18
			var mid: Vector2 = c + Vector2.from_angle(ang2) * r * 0.72
			draw_line(c + Vector2.from_angle(ang2) * r * 0.35, mid, Color(0.85, 0.95, 1.0, crystal_strength * 0.35), 1.0, true)
	# Glass shell ring (exhale / second hold)
	if shell_alpha > 0.001:
		draw_arc(c, r * 1.02, 0.0, TAU, 72, Color(0.82, 0.94, 1.0, shell_alpha), 2.8, true)
		draw_arc(c, r * 0.96, 0.0, TAU, 72, Color(1.0, 1.0, 1.0, shell_alpha * 0.35), 1.2, true)
