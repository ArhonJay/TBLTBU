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

<<<<<<< Updated upstream
=======
var target_zoom: float = 0.0
var min_zoom: float = 0.0
var max_zoom: float = 4.0
var zoom_step: float = 0.4
var base_camera_y: float

# --- DRONE ---
var drone_battery_seconds: float = 0.0   # extra flight time added by batteries

# --- HEALTH SYSTEM ---
@export var max_health: int = 100
var current_health: int = 100
var is_dead: bool = false

# --- HURT FLASH ---
var _hurt_flash_timer: float = 0.0
var _hurt_flash_duration: float = 0.4
@onready var hurt_overlay: ColorRect = $HealthbarUI/Control/HurtOverlay

# --- STAMINA ---
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0   # per second while sprinting
@export var stamina_regen_rate: float = 12.0   # per second while not sprinting
@export var stamina_regen_delay: float = 1.5   # seconds before regen starts after stopping
var current_stamina: float = 100.0
var _stamina_regen_timer: float = 0.0
var _stamina_exhausted: bool = false           # true only when stamina hits exactly 0

>>>>>>> Stashed changes
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
	
	var spawn_point = get_tree().current_scene.get_node("SpawnPoints/ExplorerSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

# --- COMBINED INPUT FUNCTION ---
func _input(event):
	# 1. Handle mouse movement for looking around
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

<<<<<<< Updated upstream
	# 2. Handle Door Interaction using your existing "interaction" raycast
	if event.is_action_pressed("interact"): 
		if interaction.is_colliding():
			var hit_object = interaction.get_collider()
			if hit_object != null:
				var root_object = hit_object.get_parent() 
				# Check if the thing we hit actually has the interact function
				if root_object != null and root_object.has_method("interact"):
					root_object.interact()
=======
	if event.is_action_pressed("use_item"):
		use_item()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += zoom_step
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)
>>>>>>> Stashed changes

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

# --- USE ITEM (hotbar) ---
func use_item() -> void:
	var inv := get_node_or_null("InventoryUI")
	if inv == null:
		return
	var item = inv.get_selected_item()
	if item == null:
		return
	var item_id : String = item.get("id", "")
	match item_id:
		"medkit":
			var amount : int = item.get("heal_amount", 50)
			heal(amount)
			inv.remove_selected_item()
			print("Used Medkit — healed %d HP." % amount)
		"battery":
			var bonus : int = item.get("flight_bonus", 5)
			drone_battery_seconds += float(bonus)
			inv.remove_selected_item()
			print("Used Drone Battery — +%ds flight time. Total bonus: %.0fs" % [bonus, drone_battery_seconds])
			_show_use_popup("+%d seconds drone flight time" % bonus, Color(0.25, 0.85, 0.35, 1.0))
		_:
			print("No use action defined for item: ", item_id)


# ── Item-use feedback popup (bottom-centre, brief) ────────────────────────────
func _show_use_popup(message: String, accent: Color) -> void:
	var popup_name := "_UsePopup"
	var old := get_node_or_null(popup_name)
	if old:
		old.queue_free()

	var layer := CanvasLayer.new()
	layer.name  = popup_name
	layer.layer = 11
	add_child(layer)

	var panel := PanelContainer.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color           = Color(0.05, 0.05, 0.07, 0.85)
	ps.set_corner_radius_all(8)
	ps.border_width_top    = 0; ps.border_width_bottom = 2
	ps.border_width_left   = 0; ps.border_width_right  = 0
	ps.border_color        = accent
	ps.content_margin_top    = 10.0; ps.content_margin_bottom = 10.0
	ps.content_margin_left   = 20.0; ps.content_margin_right  = 20.0
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top    = 0.82
	panel.anchor_bottom = 0.82
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)

	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", accent)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.8)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(layer.queue_free)

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
