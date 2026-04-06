extends CanvasLayer
## Burner (panic jets) + Social Battery segments.

@onready var _burner: Control = $Margin/HBox/BurnerColumn/BurnerRow/BurnerHost
@onready var _shield: Label = $Margin/HBox/BurnerColumn/BurnerRow/ShieldBadge
@onready var _battery: HBoxContainer = $Margin/HBox/BatteryColumn/BatteryHost


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_burner.add_to_group("celestial_heat_meter")
	_refresh_all()
	if not Dialogic.VAR.variable_changed.is_connected(_on_var_changed):
		Dialogic.VAR.variable_changed.connect(_on_var_changed)


func _on_var_changed(info: Dictionary) -> void:
	var v: String = str(info.get("variable", ""))
	if v == "panic_points" or v == "social_battery" or v == "panic_shield":
		_refresh_all()


func _refresh_all() -> void:
	if _burner and _burner.has_method("refresh"):
		_burner.refresh()
	_paint_battery()
	_refresh_shield()


func _refresh_shield() -> void:
	if _shield == null:
		return
	var sh: int = CelestialVNState.get_panic_shield()
	_shield.visible = sh > 0
	_shield.text = "🛡"
	_shield.tooltip_text = "Tempering Shield: Prevents the next %d points of Heat." % sh


func _paint_battery() -> void:
	if _battery == null:
		return
	var soc: int = CelestialVNState.get_social_battery()
	for i in _battery.get_child_count():
		var c: ColorRect = _battery.get_child(i) as ColorRect
		if c == null:
			continue
		var idx: int = i + 1
		var on: bool = idx <= soc
		if not on:
			c.color = Color(0.15, 0.15, 0.18, 0.9)
			continue
		if idx <= 4:
			c.color = Color(0.25, 0.78, 0.35)
		elif idx <= 6:
			c.color = Color(0.92, 0.86, 0.2)
		elif idx <= 8:
			c.color = Color(0.95, 0.55, 0.15)
		else:
			c.color = Color(0.9, 0.2, 0.22)
