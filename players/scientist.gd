extends CharacterBody3D

@export var move_speed: float = 20.0
@export var run_speed: float = 50.0
@export var jump_force: float = 20.0 # NEW: Added jump force!
@export var gravity: float = 50.0 # Adjusted gravity to match jump (12 is too floaty for a jump of 20!)
@onready var interaction_ray: RayCast3D = $Camera3D/Interaction
# --- CAMERA VARIABLES ---
const MOUSE_SENSITIVITY = 0.002
@export var look_sensitivity: float = 2.0
var min_look_angle: float = -90.0
var max_look_angle: float = 90.0
var mouse_delta: Vector2 = Vector2()
@onready var camera = $SpringArm3D/Camera 
@onready var hand = get_node("SpringArm3D/Camera/Hand")  

# --- ZOOM VARIABLES ---
var target_zoom: float = 0.0
var min_zoom: float = 0.0 # First-person distance
var max_zoom: float = 4.0 # Furthest third-person distance
var zoom_step: float = 0.4 # How much one scroll wheel click moves the camera
var base_camera_y: float # To remember the original height

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not is_multiplayer_authority():
		camera.current = false 
		set_physics_process(false) 
		set_process(false)       # Disable _process for network clones
		set_process_input(false) # Disable input for network clones
		return 
		
	camera.current = true
	$SpringArm3D.add_excluded_object(get_rid())
	
	# Save the camera's starting height and set initial target
	base_camera_y = camera.position.y
	target_zoom = camera.position.z
	
	# Hide the scientist's body initially (CHANGE THIS NAME IF NEEDED!)
	$Mage.hide() 
	
	# Capture the mouse pointer so it doesn't leave the game window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var spawn_point = get_tree().current_scene.get_node_or_null("SpawnPoints/ScientistSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

# --- CATCH MOUSE MOVEMENTS AND SCROLLING ---
func _input(event):
	# 1. Look around
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

	# 2. Scroll Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= zoom_step # Zoom IN
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += zoom_step # Zoom OUT
			
		# Keep the zoom within our limits
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)

	
# --- APPLY CAMERA ROTATION AND ZOOM ---
func _process(delta):
	# THE FIX: Rotate the SpringArm up and down, NOT the camera!
	$SpringArm3D.rotation_degrees.x -= mouse_delta.y * look_sensitivity * delta
	$SpringArm3D.rotation_degrees.x = clamp($SpringArm3D.rotation_degrees.x, min_look_angle, max_look_angle)
	
	# Left/Right still rotates the whole character body, which is correct
	rotation_degrees.y -= mouse_delta.x * look_sensitivity * delta
	
	if $SpringArm3D.spring_length < 0.8: # We check the arm length now!
		$Mage.hide()
	else:
		$Mage.show()
	
	# Reset the delta so it doesn't spin infinitely
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
	# --- 1. CALCULATE CURRENT SPEED ---
	var current_speed = move_speed
	# If the player is holding down our new sprint button, use the faster speed!
	if Input.is_action_pressed("sprint"):
		current_speed = run_speed

	# --- 2. APPLY MOVEMENT ---
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		# Use current_speed instead of move_speed here!
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		
		var target_angle = atan2(-input_dir.x, -input_dir.y) + PI
		$Mage.rotation.y = lerp_angle($Mage.rotation.y, target_angle, 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# --- 3. THE ANIMATION PRIORITY BLOCK ---
	if not is_on_floor():
		# Priority 1: We are in the air
		if velocity.y > 0:
			$AnimationPlayer.play("jump_start") 
		else:
			$AnimationPlayer.play("jump_idle")  
			
	elif direction:
		# Priority 2: We are on the ground AND moving
		if Input.is_action_pressed("sprint"):
			$AnimationPlayer.play("running") # Make sure you have a "run" animation loaded!
		else:
			$AnimationPlayer.play("walk")
		
	else:
		# Priority 3: We are on the ground AND standing still
		$AnimationPlayer.play("idle")

	move_and_slide()

# Added this so your Scientist can also press Escape to get their mouse cursor back!
func window_activity():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
