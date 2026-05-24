extends Node3D # Change this to MeshInstance3D if Laboratory is a MeshInstance

# Called when the node enters the scene tree for the first time.
func _ready():
	# Ensure the laboratory is invisible by default when the scene loads
	hide() 

# Connect this function to the 'body_entered' signal of your Area3D
func _on_detection_zone_body_entered(body):
	# Check if the object entering is actually a player. 
	# (Make sure your player nodes are added to a group called "player")
	if body.is_in_group("player"):
		show()

# Connect this function to the 'body_exited' signal of your Area3D
func _on_detection_zone_body_exited(body):
	if body.is_in_group("player"):
		hide()
