extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_force: float = 5.0
@export var gravity: float = 12.0
@export var look_sensitivity: float = 0.5
var min_look_angle: float = -90.0
var max_look_angle: float = 90.0
var mouse_delta: Vector2 = Vector2()
@onready var interact_ui = $CanvasLayer/Label
@onready var camera = $Camera 
@onready var interaction = get_node("Camera/Interaction") 
@onready var hand = get_node("Camera/Hand")            

var picked_object: RigidBody3D = null
var pull_power: float = 4.0

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
	
	# THE FIX: Hide my own body from my own camera so I can see!
	$MeshInstance3D.hide() 
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	var spawn_point = get_tree().current_scene.get_node("SpawnPoints/ExplorerSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

# --- COMBINED INPUT FUNCTION ---
func _input(event):
	# 1. Handle mouse movement for looking around
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

	# 2. Handle Door Interaction using your existing "interaction" raycast
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
	
	mouse_delta = Vector2()
	window_activity()
	
	# Check the UI every frame!
	check_interaction_raycast()

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
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

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
			
func check_interaction_raycast():
	# Assume we shouldn't show the text unless proven otherwise
	interact_ui.hide()
	
	if interaction.is_colliding():
		var hit_object = interaction.get_collider()
		if hit_object != null:
			var root_object = hit_object.get_parent() 
			# If the thing we are looking at has the interact() script, show the text!
			if root_object != null and root_object.has_method("interact"):
				interact_ui.show()
