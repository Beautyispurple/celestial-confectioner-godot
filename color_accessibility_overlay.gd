extends CanvasLayer
## Fullscreen colorblind simulation below pause UI (layer 100). Uses backbuffer + shader.

const SHADER: Shader = preload("res://ui/colorblind_filter.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	visible = true


func set_colorblind(preset: int, strength: float) -> void:
	if _mat == null:
		return
	var p: int = clampi(preset, 0, 3)
	var s: float = clampf(strength, 0.0, 1.0)
	_mat.set_shader_parameter("filter_mode", p)
	_mat.set_shader_parameter("strength", s)
	var active: bool = p != 0 and s > 0.001
	_rect.visible = active
