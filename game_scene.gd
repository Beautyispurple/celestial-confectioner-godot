extends Node2D

func _ready():
	# This must be indented (pushed to the right) 
	# so it stays 'inside' the function.
	Dialogic.start("intro_sequence")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
