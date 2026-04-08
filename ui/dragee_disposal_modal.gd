extends CanvasLayer
## Single-line prompt with Confirm / Cancel. Await present() for result.

signal settled(text: String, cancelled: bool)
## true = helpful (keep), false = not helpful (dispose path). Emitted only from present_helpful_choice.
signal helpful_chosen(helpful: bool)
signal helpful_cancelled

const _LAYER := 95

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var _line: LineEdit = $Center/Panel/Margin/VBox/LineEdit
@onready var _confirm: Button = $Center/Panel/Margin/VBox/Buttons/Confirm
@onready var _cancel: Button = $Center/Panel/Margin/VBox/Buttons/Cancel
@onready var _choice_row: HBoxContainer = $Center/Panel/Margin/VBox/ChoiceRow
@onready var _btn_helpful: Button = $Center/Panel/Margin/VBox/ChoiceRow/BtnHelpful
@onready var _btn_not_helpful: Button = $Center/Panel/Margin/VBox/ChoiceRow/BtnNotHelpful
@onready var _button_row: HBoxContainer = $Center/Panel/Margin/VBox/Buttons

var _pending: bool = false
var _confirm_only: bool = false
var _helpful_mode: bool = false


func _ready() -> void:
	layer = _LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_confirm.pressed.connect(_on_confirm)
	_cancel.pressed.connect(_on_cancel)
	_line.text_submitted.connect(_on_submitted.unbind(1))
	_btn_helpful.pressed.connect(_on_helpful)
	_btn_not_helpful.pressed.connect(_on_not_helpful)


func present_helpful_choice(title: String) -> void:
	_helpful_mode = true
	_confirm_only = false
	_line.visible = false
	_choice_row.visible = true
	_buttons_visible(false)
	_pending = true
	_title.text = title
	visible = true
	_btn_helpful.grab_focus()


func _buttons_visible(v: bool) -> void:
	_button_row.visible = v


func present(title: String, placeholder: String = "", initial: String = "") -> void:
	_helpful_mode = false
	_confirm_only = false
	_line.visible = true
	_choice_row.visible = false
	_buttons_visible(true)
	_pending = true
	_title.text = title
	_line.placeholder_text = placeholder
	_line.text = initial
	visible = true
	_line.grab_focus()
	_line.caret_column = _line.text.length()


func present_confirm(title: String) -> void:
	_helpful_mode = false
	_confirm_only = true
	_line.visible = false
	_choice_row.visible = false
	_buttons_visible(true)
	_pending = true
	_title.text = title
	visible = true
	_confirm.grab_focus()


func close_modal() -> void:
	visible = false
	_pending = false
	_helpful_mode = false
	_choice_row.visible = false
	_button_row.visible = true
	_line.release_focus()


func _finish(text: String, cancelled: bool) -> void:
	if not _pending:
		return
	close_modal()
	settled.emit(text, cancelled)


func _on_confirm() -> void:
	if _confirm_only:
		_finish("", false)
	else:
		_finish(_line.text.strip_edges(), false)


func _on_cancel() -> void:
	_finish("", true)


func _on_submitted() -> void:
	_on_confirm()


func _on_helpful() -> void:
	if not _pending or not _helpful_mode:
		return
	close_modal()
	helpful_chosen.emit(true)


func _on_not_helpful() -> void:
	if not _pending or not _helpful_mode:
		return
	close_modal()
	helpful_chosen.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _pending:
		return
	if _helpful_mode:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_helpful_cancel()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


func _on_helpful_cancel() -> void:
	if not _pending or not _helpful_mode:
		return
	close_modal()
	helpful_cancelled.emit()
