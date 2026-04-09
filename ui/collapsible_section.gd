extends VBoxContainer
## Header button toggles body visibility.

signal toggled_expanded(is_expanded: bool)

@onready var _header: Button = $HeaderButton
@onready var _body: MarginContainer = $BodyMargin
@onready var _body_rt: RichTextLabel = $BodyMargin/BodyRichText

var _expanded: bool = false
var _title_base: String = ""


func _ready() -> void:
	_header.pressed.connect(_on_header_pressed)
	if not _body_rt.meta_clicked.is_connected(_on_body_meta_clicked):
		_body_rt.meta_clicked.connect(_on_body_meta_clicked)
	_apply()


func _on_body_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func _on_header_pressed() -> void:
	_expanded = not _expanded
	_apply()
	toggled_expanded.emit(_expanded)


func _apply() -> void:
	_body.visible = _expanded
	_header.text = ("▼ " if _expanded else "▶ ") + _title_base


func set_title(title: String) -> void:
	_title_base = title
	_apply()


func set_body_bbcode(bbcode: String) -> void:
	_body_rt.text = bbcode
