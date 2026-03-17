extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed():
	# This line tells Godot to switch from the Menu to the Game World
	get_tree().change_scene_to_file("res://game_scene.tscn")
	
	# We move the Dialogic start command to the Game Scene's script 
	# so it starts once the room is loaded!
#test
func _on_quit_button_pressed():
	# This closes the game window.
	get_tree().quit()
