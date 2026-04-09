extends Control
## Pause overlay: Safety & Support copy + collapsible USA resources (same block as consent Screen C).

signal closed

@onready var _top: RichTextLabel = $Center/Panel/Margin/VBox/Scroll/InnerVBox/TopCopy
@onready var _col: Node = $Center/Panel/Margin/VBox/Scroll/InnerVBox/CollapsibleSection
@onready var _back: Button = $Center/Panel/Margin/VBox/BackButton


func _ready() -> void:
	visible = false
	hide()
	_back.pressed.connect(_on_back_pressed)
	_top.text = _TOP_COPY_BBCODE
	if not _top.meta_clicked.is_connected(_on_top_meta_clicked):
		_top.meta_clicked.connect(_on_top_meta_clicked)
	if _col.has_method(&"set_title"):
		_col.call(&"set_title", "Crisis & support resources (USA)")
	if _col.has_method(&"set_body_bbcode"):
		_col.call(&"set_body_bbcode", CrisisResourcesText.USA_CRISIS_RESOURCES_BBCODE)
	_style_collapsible(_col)
	_back.add_theme_color_override("font_color", Color.WHITE)
	_back.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9))
	_back.add_theme_font_size_override("font_size", 24)


const _TOP_COPY_BBCODE := """If you’re feeling overwhelmed, it’s okay to pause, step away, or ask for help.

[br]

This game is peer support practice—not therapy, not medical advice, not a diagnosis, and not crisis care. The tools here are not a replacement for professional support when you need it, and the game makes no guarantees about outcomes."""


func _style_collapsible(col: Node) -> void:
	var header: Button = col.get_node_or_null("HeaderButton") as Button
	if header:
		header.add_theme_color_override("font_color", Color.WHITE)
		header.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85))
	var rt: RichTextLabel = col.get_node_or_null("BodyMargin/BodyRichText") as RichTextLabel
	if rt:
		rt.add_theme_color_override("default_color", Color.WHITE)
		rt.add_theme_color_override("font_selected_color", Color(0.65, 0.85, 1.0))


func present() -> void:
	visible = true
	show()


func _on_top_meta_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))


func hide_panel() -> void:
	if not visible:
		return
	visible = false
	hide()
	closed.emit()


func _on_back_pressed() -> void:
	hide_panel()
