extends CharacterBody3D

@export var speed: float = 8.0

# NEW: Add a gravity multiplier!
var gravity: float = 12.0 

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		$Camera3D.current = false 
		set_physics_process(false) 
		return 
		
	$Camera3D.current = true
	var spawn_point = get_tree().current_scene.get_node_or_null("SpawnPoints/ScientistSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

func _physics_process(delta):
	
	# NEW: If we are not touching the floor, pull the drone down!
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
