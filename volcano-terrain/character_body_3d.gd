extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

@onready var camera = $Camera3D

func _ready():
	# This hides the mouse and locks it to the center of the screen
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	# Check if the mouse is moving
	if event is InputEventMouseMotion:
		# Rotate the whole player left/right (Y-axis)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Rotate only the camera up/down (X-axis)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		
		# Prevent the camera from flipping upside down
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _physics_process(delta: float) -> void:
	# Add the gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# We use 'transform.basis' so that "Forward" is always the direction 
	# the player is currently facing after rotating with the mouse
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"): # Usually mapped to ESC
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
