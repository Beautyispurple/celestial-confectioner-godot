extends Control
## Backpack button (anchored left of Dialogic textbox) opens centered 5×5 scrollable inventory modal.

const GRID_SLOTS := 25

@onready var _bag_anchor: Control = $BagAnchor
@onready var _bag_button: TextureButton = $BagAnchor/BagButton
@onready var _modal: CanvasLayer = $InventoryModal
@onready var _dim: ColorRect = $InventoryModal/DimRect
@onready var _item_grid: GridContainer = $InventoryModal/Center/MainPanel/Margin/VBox/Scroll/ItemGrid
@onready var _title: Label = $InventoryModal/Center/MainPanel/Margin/VBox/TitleLabel
@onready var _gold_label: Label = $InventoryModal/Center/MainPanel/Margin/VBox/GoldRow/GoldLabel
@onready var _close_button: Button = $InventoryModal/Center/MainPanel/Margin/VBox/CloseButton

var _popup: PopupMenu
var _slot_buttons: Array[Button] = []

var _item_column: Array[String] = [
	GlobalInventory.ITEM_SUGAR,
	GlobalInventory.ITEM_WATER,
	GlobalInventory.ITEM_CHILI,
	GlobalInventory.ITEM_PHONE,
]

var _pos_tick: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(true)
	_bag_button.ignore_texture_size = true
	_bag_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_bag_button.pressed.connect(_toggle_inventory_modal)
	_close_button.pressed.connect(_close_inventory_modal)
	_dim.gui_input.connect(_on_dim_gui_input)
	_popup = PopupMenu.new()
	add_child(_popup)
	_popup.id_pressed.connect(_on_popup_id)
	GlobalInventory.inventory_changed.connect(_refresh_labels)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	if not Dialogic.VAR.variable_changed.is_connected(_on_dialogic_var_changed):
		Dialogic.VAR.variable_changed.connect(_on_dialogic_var_changed)
	_build_slots()
	_refresh_labels()
	_refresh_gold_label()
	_modal.visible = false
	call_deferred("_update_bag_anchor_position")


func _on_viewport_size_changed() -> void:
	_update_bag_anchor_position()


func _on_dialogic_var_changed(info: Dictionary) -> void:
	if str(info.get("variable", "")) == "gold_coin":
		_refresh_gold_label()


func _refresh_gold_label() -> void:
	if _gold_label == null:
		return
	var raw: Variant = Dialogic.VAR.get_variable("gold_coin", 0)
	var n: float = 0.0
	if raw is float or raw is int:
		n = float(raw)
	else:
		var s := str(raw).strip_edges()
		if s.is_valid_float():
			n = float(s)
		elif s.is_valid_int():
			n = float(int(s))
	# Whole gold for display; negatives allowed (overdraft story beats).
	var shown: int = int(roundf(n))
	_gold_label.text = "%d G" % shown


func _process(_delta: float) -> void:
	if not visible or not is_visible_in_tree():
		return
	_pos_tick += 1
	if _pos_tick % 4 != 0:
		return
	_update_bag_anchor_position()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree() and _modal.visible:
			_close_inventory_modal()


func _find_dialog_text_panel() -> Control:
	if not Dialogic.Styles.has_active_layout_node():
		return null
	var layout: Node = Dialogic.Styles.get_layout_node()
	if layout == null:
		return null
	var p: Node = layout.find_child("DialogTextPanel", true, false)
	return p as Control


func _update_bag_anchor_position() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var btn_size: Vector2 = _bag_button.size
	if btn_size.x < 2.0:
		btn_size = _bag_button.get_combined_minimum_size()
	if btn_size.x < 2.0:
		btn_size = Vector2(56, 56)
	var panel := _find_dialog_text_panel()
	if panel != null and panel.is_visible_in_tree():
		var r: Rect2 = panel.get_global_rect()
		if r.size.x > 4.0 and r.size.y > 4.0:
			var gap := 14.0
			var x: float = r.position.x - gap - btn_size.x
			var y: float = r.position.y + r.size.y - btn_size.y
			_bag_anchor.global_position = Vector2(x, y)
			return
	var vr: Rect2 = vp.get_visible_rect()
	_bag_anchor.global_position = Vector2(200, vr.size.y - 32.0 - btn_size.y)


func _toggle_inventory_modal() -> void:
	if _modal.visible:
		_close_inventory_modal()
	else:
		_open_inventory_modal()


func _open_inventory_modal() -> void:
	_modal.visible = true
	CelestialVNState.begin_blocking_overlay_vn()
	_refresh_labels()
	_refresh_gold_label()


func _close_inventory_modal() -> void:
	if not _modal.visible:
		return
	_modal.visible = false
	_popup.hide()
	CelestialVNState.end_blocking_overlay_vn()


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_inventory_modal()


func _unhandled_input(event: InputEvent) -> void:
	if not _modal.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_inventory_modal()
		get_viewport().set_input_as_handled()


func _build_slots() -> void:
	for c in _item_grid.get_children():
		c.queue_free()
	_slot_buttons.clear()
	for i in GRID_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 72)
		b.clip_text = true
		if i < _item_column.size():
			var id: String = _item_column[i]
			b.pressed.connect(_on_item_pressed.bind(id))
		else:
			b.disabled = true
			b.focus_mode = Control.FOCUS_NONE
		_item_grid.add_child(b)
		_slot_buttons.append(b)
	_title.text = "Marzi's bag"


func _refresh_labels() -> void:
	if _slot_buttons.size() < 4:
		return
	_slot_buttons[0].text = "Sugar\n×%d" % GlobalInventory.get_count(GlobalInventory.ITEM_SUGAR)
	_slot_buttons[1].text = "Water\n×%d" % GlobalInventory.get_count(GlobalInventory.ITEM_WATER)
	_slot_buttons[2].text = "Chili\n×%d" % GlobalInventory.get_count(GlobalInventory.ITEM_CHILI)
	var ph: int = GlobalInventory.get_count(GlobalInventory.ITEM_PHONE)
	_slot_buttons[3].text = "Phone\n%s" % (("(key)") if ph > 0 else "×0")
	for i in range(4, _slot_buttons.size()):
		_slot_buttons[i].text = "—"
		_slot_buttons[i].disabled = true


var _pending_item: String = ""


func _on_item_pressed(item_id: String) -> void:
	_pending_item = item_id
	_popup.clear()
	match item_id:
		GlobalInventory.ITEM_SUGAR:
			_popup.add_item("Eat", 0)
			_popup.add_item("Throw away", 1)
		GlobalInventory.ITEM_WATER:
			_popup.add_item("Drink", 0)
			_popup.add_item("Throw away", 1)
		GlobalInventory.ITEM_CHILI:
			_popup.add_item("Eat", 0)
			_popup.add_item("Throw away", 1)
		GlobalInventory.ITEM_PHONE:
			_popup.add_item("Call a friend", 0)
	var center := get_viewport().get_visible_rect().get_center()
	_popup.popup(Rect2i(Vector2i(center), Vector2i(1, 1)))


func _on_popup_id(id: int) -> void:
	var item := _pending_item
	match item:
		GlobalInventory.ITEM_SUGAR:
			if id == 0:
				GlobalInventory.eat_sugar()
			elif id == 1:
				GlobalInventory.throw_away_one(GlobalInventory.ITEM_SUGAR)
		GlobalInventory.ITEM_WATER:
			if id == 0:
				GlobalInventory.drink_water()
			elif id == 1:
				GlobalInventory.throw_away_one(GlobalInventory.ITEM_WATER)
		GlobalInventory.ITEM_CHILI:
			if id == 0:
				GlobalInventory.eat_chili()
			elif id == 1:
				GlobalInventory.throw_away_one(GlobalInventory.ITEM_CHILI)
		GlobalInventory.ITEM_PHONE:
			if id == 0:
				GlobalInventory.call_friend()
	_refresh_labels()
