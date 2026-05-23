extends CharacterBody3D

@export var move_speed: float = 20.0
@export var climb_speed: float = 10.0
@export var run_speed: float = 50.0
@export var jump_force: float = 50.0
var wall_jump_cooldown: float = 0.0 # NEW: Prevents instantly re-grabbing the wall

@export var gravity: float = 50.0
@export var look_sensitivity: float = 2.0
var min_look_angle: float = -90.0
var max_look_angle: float = 90.0
var mouse_delta: Vector2 = Vector2()
@onready var camera = $SpringArm3D/Camera 
@onready var hand = get_node("SpringArm3D/Camera/Hand")         

var picked_object: RigidBody3D = null
var pull_power: float = 4.0

# Replace the toggle variables with these:
var target_zoom: float = 0.0
var min_zoom: float = 0.0 # First-person distance
var max_zoom: float = 4.0 # Furthest third-person distance
var zoom_step: float = 0.4 # How much one scroll wheel click moves the camera
var base_camera_y: float # To remember the original height

func _enter_tree():
	# The moment this node spawns, look at its name (e.g., "9334...") 
	# and assign authority to that specific player ID.
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		camera.current = false 
		set_physics_process(false) 
		set_process(false) 
		set_process_input(false) 
		return 
		
	# I AM THE OWNER! Activate my stuff.
	camera.current = true
	$SpringArm3D.add_excluded_object(get_rid())
	
	# Save the camera's starting height and set initial target
	base_camera_y = camera.position.y
	target_zoom = camera.position.z
	
	# THE FIX: Hide my own body from my own camera so I can see!
	$Barbarian.hide() 
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var spawn_point = get_tree().current_scene.get_node("SpawnPoints/ExplorerSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

# --- COMBINED INPUT FUNCTION ---
func _input(event):
	# 1. Handle mouse movement for looking around
	if event is InputEventMouseMotion:
		mouse_delta = event.relative
		
	# 2. Handle Mouse Scroll Zooming
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= zoom_step # Zoom IN
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += zoom_step # Zoom OUT
			
		# Keep the zoom within our limits
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)

# --- ONLY ONE _PROCESS FUNCTION HERE ---
func _process(delta):
	# THE FIX: Rotate the SpringArm up and down, NOT the camera!
	$SpringArm3D.rotation_degrees.x -= mouse_delta.y * look_sensitivity * delta
	$SpringArm3D.rotation_degrees.x = clamp($SpringArm3D.rotation_degrees.x, min_look_angle, max_look_angle)
	
	# Left/Right still rotates the whole character body, which is correct
	rotation_degrees.y -= mouse_delta.x * look_sensitivity * delta
	
	if $SpringArm3D.spring_length < 0.8: # We check the arm length now!
		$Barbarian.hide()
	else:
		$Barbarian.show()
	
	mouse_delta = Vector2()
	window_activity()

func _physics_process(delta):
	# Optional: Slightly lift the camera up as it zooms out so it looks over the Barbarian's shoulder
	var height_boost = target_zoom * 0.3
	$SpringArm3D.spring_length = lerp($SpringArm3D.spring_length, target_zoom, 10.0 * delta)
	camera.position.y = lerp(camera.position.y, base_camera_y + height_boost, 10.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	# --- 1. GET INPUT ---
	var current_speed = move_speed
	if Input.is_action_pressed("sprint"):
		current_speed = run_speed

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# TICK DOWN THE COOLDOWN TIMER
	if wall_jump_cooldown > 0.0:
		wall_jump_cooldown -= delta
		
	# --- 2. CHECK CLIMBING STATE ---
	var is_climbing = false
	
	# ONLY allow climbing if the cooldown is at zero!
	if $Barbarian/ClimbCheck.is_colliding() and wall_jump_cooldown <= 0.0:
		var hit_normal = $Barbarian/ClimbCheck.get_collision_normal()
		if hit_normal.y < 0.6 and hit_normal.y > -0.6:
			if Input.is_action_pressed("move_forward") or not is_on_floor():
				is_climbing = true

	# --- 3. APPLY PHYSICS ---
	if is_climbing:
		
		# WALL JUMPING!
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force * 0.8 # Jump up slightly weaker than a ground jump
			
			# Push the Barbarian BACKWARDS, away from the wall
			var backward_dir = $Barbarian.global_transform.basis.z.normalized()
			velocity.x = backward_dir.x * (move_speed * 1.5)
			velocity.z = backward_dir.z * (move_speed * 1.5)
			
			# Start the cooldown so we don't instantly glue back to the wall!
			wall_jump_cooldown = 0.3 
			is_climbing = false
			
		else:
			# Normal Climbing Physics
			velocity.y = -input_dir.y * climb_speed
			velocity.x = direction.x * (move_speed * 0.5)
			velocity.z = direction.z * (move_speed * 0.5)
		
	else:
		# NORMAL PHYSICS: Gravity and Walking
		if not is_on_floor():
			velocity.y -= gravity * delta
			
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_force

		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			
			var target_angle = atan2(-input_dir.x, -input_dir.y) + PI
			$Barbarian.rotation.y = lerp_angle($Barbarian.rotation.y, target_angle, 15.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
	
# --- 4. THE ANIMATION PRIORITY BLOCK ---
	if is_climbing:
		# Priority 0: We are climbing!
		if input_dir.y != 0:
			$AnimationPlayer.play("climb") # Make sure to extract a climb.res!
		else:
			$AnimationPlayer.play("jump_idle") # Hanging still on the ladder
			
	elif not is_on_floor():
		# Priority 1: We are falling/jumping
		if velocity.y > 0:
			$AnimationPlayer.play("jump_start") 
		elif velocity.y < -3.0: 
			$AnimationPlayer.play("jump_idle")  
			
	elif direction:
		# Priority 2: We are on the ground AND moving
		if Input.is_action_pressed("sprint"):
			$AnimationPlayer.play("running") 
		else:
			$AnimationPlayer.play("walk")
		
	else:
		# Priority 3: We are on the ground AND standing still
		$AnimationPlayer.play("idle")

	move_and_slide()

func window_activity():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
