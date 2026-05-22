extends CharacterBody3D

@export var speed: float = 50.0

# NEW: Add a gravity multiplier!
var gravity: float = 12.0 

# --- CAMERA VARIABLES ---
@export var look_sensitivity: float = 2.0
var min_look_angle: float = -90.0
var max_look_angle: float = 90.0
var mouse_delta: Vector2 = Vector2()
@onready var camera = $Camera3D # Matching your Scientist's node name

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		$Camera3D.current = false 
		set_physics_process(false) 
		set_process(false)       # Disable _process for network clones
		set_process_input(false) # Disable input for network clones
		return 
		
	$Camera3D.current = true
	
	# Capture the mouse pointer so it doesn't leave the game window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var spawn_point = get_tree().current_scene.get_node_or_null("SpawnPoints/ScientistSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

# --- CATCH MOUSE MOVEMENTS ---
func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

# --- APPLY CAMERA ROTATION ---
func _process(delta):
	# Up and down (Pitch)
	camera.rotation_degrees.x -= mouse_delta.y * look_sensitivity * delta
	camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, min_look_angle, max_look_angle)
	
	# Left and right (Yaw)
	rotation_degrees.y -= mouse_delta.x * look_sensitivity * delta
	
	# Reset the delta so it doesn't spin infinitely
	mouse_delta = Vector2()

func _physics_process(delta):
	
	# If we are not touching the floor, pull the drone down!
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# CRITICAL FIX: Use transform.basis so the character moves exactly where they are looking
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
