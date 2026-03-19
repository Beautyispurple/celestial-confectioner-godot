extends Control

var hand_angle: float = 0.0
var is_active: bool = false

func _ready():
	self.visible = false
	
	if Dialogic:
		Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_dialogic_signal(argument: String):
	if argument == "timelapse":
		run_clock_sequence()

func run_clock_sequence():
	self.visible = true
	hand_angle = 0.0 
	
	var tween = create_tween()
	
	tween.tween_property(self, "hand_angle", TAU * 2, 3.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	
	await tween.finished
	self.visible = false

func _process(_delta):
	if self.visible:
		queue_redraw() 

func _draw():
	var center = size / 2
	var radius = 60.0
	var hand_length = 50.0
	
	draw_arc(center, radius, 0, TAU, 64, Color.ANTIQUE_WHITE, 4.0, true)
	
	var hand_end = center + Vector2(cos(hand_angle - PI/2), sin(hand_angle - PI/2)) * hand_length
	
	draw_line(center, hand_end, Color.GOLD, 5.0, true)
	
	draw_circle(center, 5.0, Color.GOLD)
