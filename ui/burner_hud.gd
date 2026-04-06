extends Control

const JET_COUNT := 5


func _draw() -> void:
	var pts: int = CelestialVNState.get_panic_points()
	var lit: int = mini(floori(pts / 2.0), JET_COUNT)
	var center := size / 2.0
	var r_outer: float = minf(size.x, size.y) * 0.42
	var r_inner: float = r_outer * 0.62
	for i in JET_COUNT:
		var a0: float = TAU * float(i) / float(JET_COUNT) - PI / 2.0
		var a1: float = TAU * float(i + 1) / float(JET_COUNT) - PI / 2.0 - 0.08
		var poly := PackedVector2Array()
		poly.append(center + Vector2(cos(a0), sin(a0)) * r_inner)
		poly.append(center + Vector2(cos(a0), sin(a0)) * r_outer)
		poly.append(center + Vector2(cos(a1), sin(a1)) * r_outer)
		poly.append(center + Vector2(cos(a1), sin(a1)) * r_inner)
		var active: bool = i < lit
		var col := Color(0.35, 0.55, 1.0, 0.95) if active else Color(0.12, 0.12, 0.14, 0.85)
		draw_colored_polygon(poly, col)
		if active:
			var flame_h: float = (r_outer - r_inner) * 1.1
			var mid_a: float = (a0 + a1) * 0.5
			var tip: Vector2 = center + Vector2(cos(mid_a), sin(mid_a)) * (r_outer + flame_h)
			var fpoly := PackedVector2Array()
			fpoly.append(center + Vector2(cos(a0), sin(a0)) * r_outer * 0.98)
			fpoly.append(tip)
			fpoly.append(center + Vector2(cos(a1), sin(a1)) * r_outer * 0.98)
			draw_colored_polygon(fpoly, Color(0.55, 0.45, 1.0, 0.75))


func refresh() -> void:
	queue_redraw()
