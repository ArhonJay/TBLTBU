extends CharacterBody3D

@export var move_speed: float = 20.0
@export var jump_force: float = 20.0
@export var gravity: float = 50.0
@export var look_sensitivity: float = 2.0
var min_look_angle: float = -90.0
var max_look_angle: float = 90.0
var mouse_delta: Vector2 = Vector2()
@onready var camera = $Camera 
@onready var interaction = get_node("Camera/Interaction") 
@onready var hand = get_node("Camera/Hand")            

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
		$Camera.current = false 
		set_physics_process(false) 
		set_process(false) 
		set_process_input(false) 
		return 
		
	# I AM THE OWNER! Activate my stuff.
	$Camera.current = true
	
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

	# 3. Handle Door Interaction using your existing "interaction" raycast
	if event.is_action_pressed("interact"): 
		if interaction.is_colliding():
			var hit_object = interaction.get_collider()
			if hit_object != null:
				var root_object = hit_object.get_parent() 
				# Check if the thing we hit actually has the interact function
				if root_object != null and root_object.has_method("interact"):
					root_object.interact()

# --- ONLY ONE _PROCESS FUNCTION HERE ---
func _process(delta):
	camera.rotation_degrees.x -= mouse_delta.y * look_sensitivity * delta
	camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, min_look_angle, max_look_angle)
	rotation_degrees.y -= mouse_delta.x * look_sensitivity * delta
	
	# Smoothly slide the camera backwards (Z axis)
	camera.position.z = lerp(camera.position.z, target_zoom, 10.0 * delta)
	
	# Optional: Slightly lift the camera up as it zooms out so it looks over the Barbarian's shoulder
	var height_boost = target_zoom * 0.3
	camera.position.y = lerp(camera.position.y, base_camera_y + height_boost, 10.0 * delta)
	
	# Auto-hide the Barbarian if the camera gets too close to his head!
	if camera.position.z < 0.8:
		$Barbarian.hide()
	else:
		$Barbarian.show()
	
	mouse_delta = Vector2()
	window_activity()

func _physics_process(delta):
	if Input.is_action_just_pressed("pick_up"):
		pick_objects()
	if Input.is_action_just_pressed("drop"):
		drop_objects()

	if picked_object != null:
		var a = picked_object.global_transform.origin
		var b = hand.global_transform.origin
		picked_object.set_linear_velocity((b - a) * pull_power)

	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		
		var target_angle = atan2(-input_dir.x, -input_dir.y) + PI
		$Barbarian.rotation.y = lerp_angle($Barbarian.rotation.y, target_angle, 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
	
	if not is_on_floor():
		# Priority 1: We are in the air
		if velocity.y > 0:
			$AnimationPlayer.play("jump_start") # Reaching up
		else:
			$AnimationPlayer.play("jump_idle")  # Falling down
			
	elif direction:
		# Priority 2: We are on the ground AND moving
		$AnimationPlayer.play("walk")
		
	else:
		# Priority 3: We are on the ground AND standing still
		$AnimationPlayer.play("idle")

	move_and_slide()

func pick_objects():
	var collider = interaction.get_collider()
	# This ensures we ONLY pick up physics props, not the door!
	if collider != null and collider is RigidBody3D:
		print("Test if working")
		picked_object = collider

func drop_objects():
	if picked_object != null:
		print("Dropping?")
		picked_object = null

func window_activity():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
