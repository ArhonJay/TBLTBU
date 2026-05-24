extends Node

@export var day_duration: float = 60.0
@export var start_time: float = 0.25

var time: float = start_time

@onready var sun: DirectionalLight3D = $"../sun"

func _process(delta: float) -> void:
	time += delta / day_duration
	time = fmod(time, 1.0)

	sun.rotation_degrees.x = (time * 360.0) - 90.0

	var brightness = clamp(sin(time * TAU), 0.0, 1.0)

	if brightness > 0.0:
		sun.light_energy = brightness
		sun.light_color = Color(1.0, 0.95, 0.8)
	else:
		sun.light_energy = 0.8
		sun.light_color = Color(0.2, 0.3, 0.5)
