extends CharacterBody3D

@export var safe_fall_speed: float = 100.0 # Any speed below this deals no damage
@export var fall_damage_multiplier: float = 2.0 # How much damage per extra unit of speed
var _max_downward_speed: float = 0.0
@export var move_speed: float = 20.0
@export var climb_speed: float = 10.0
@export var run_speed: float = 50.0
@export var jump_force: float = 50.0
var wall_jump_cooldown: float = 0.0

@export var gravity: float = 50.0
@export var look_sensitivity: float = 2.0
var min_look_angle: float = -90.0
var max_look_angle: float = 90.0
var mouse_delta: Vector2 = Vector2()
@onready var camera = $SpringArm3D/Camera
@onready var hand = get_node("SpringArm3D/Camera/Hand")

var picked_object: RigidBody3D = null
var pull_power: float = 4.0

var target_zoom: float = 0.0
var min_zoom: float = 0.0
var max_zoom: float = 4.0
var zoom_step: float = 0.4
var base_camera_y: float

# --- HEALTH SYSTEM ---
@export var max_health: int = 100
var current_health: int = 100
var is_dead: bool = false

# --- HURT FLASH ---
var _hurt_flash_timer: float = 0.0
var _hurt_flash_duration: float = 0.4
@onready var hurt_overlay: ColorRect = $HealthbarUI/Control/HurtOverlay

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	if not is_multiplayer_authority():
		camera.current = false
		set_physics_process(false)
		set_process(false)
		set_process_input(false)
		var hud = get_node_or_null("HealthbarUI")
		if hud:
			hud.hide()
		return

	add_to_group("explorer")
	camera.current = true
	$SpringArm3D.add_excluded_object(get_rid())

	base_camera_y = camera.position.y
	target_zoom = camera.position.z

	$Barbarian.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var spawn_point = get_tree().current_scene.get_node("SpawnPoints/ExplorerSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

	current_health = max_health
	_update_health_ui()

# --- DAMAGE & DEATH ---
func take_damage(amount: int):
	if is_dead:
		return
	current_health -= amount
	current_health = max(current_health, 0)
	_update_health_ui()
	_trigger_hurt_flash()
	print("Explorer took %d damage! HP: %d/%d" % [amount, current_health, max_health])
	if current_health <= 0:
		$AnimationPlayer.play("death")
		_die()

func heal(amount: int):
	if is_dead:
		return
	current_health += amount
	current_health = min(current_health, max_health) # Don't go over 100 max HP
	_update_health_ui()
	print("Explorer healed %d HP! HP: %d/%d" % [amount, current_health, max_health])

func _trigger_hurt_flash():
	_hurt_flash_timer = _hurt_flash_duration
	hurt_overlay.visible = true
	hurt_overlay.modulate.a = 0.55

func _update_health_ui():
	var hud = get_node_or_null("HealthbarUI")
	if hud and hud.has_method("update_health"):
		hud.update_health(current_health, max_health)

func _die():
	is_dead = true
	set_process_input(false)
	# We DO NOT set_physics_process(false) here anymore so gravity still works!
	
	print("Explorer died! Playing animation...")

	# Wait for the "death" animation to fully finish before moving on
	await $AnimationPlayer.animation_finished
	
	# Stop physics only AFTER the animation is done
	set_physics_process(false) 
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Show Game Over on ALL peers via RPC
	_show_game_over_all.rpc()

@rpc("call_local", "any_peer", "reliable")
func _show_game_over_all():
	# 1. Show on the Explorer's HUD ONLY if this machine controls the Explorer
	if is_multiplayer_authority():
		var hud = get_node_or_null("HealthbarUI")
		if hud and hud.has_method("show_game_over"):
			hud.show_game_over()

	# 2. Show on the Scientist ONLY if this machine controls the Scientist
	for player in get_tree().get_nodes_in_group("scientist"):
		if player.is_multiplayer_authority():
			if player.has_method("show_game_over_local"):
				player.show_game_over_local()

# --- INPUT ---
func _input(event):
	if is_dead:
		return
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += zoom_step
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)

func _process(delta):
	if is_dead:
		return

	# Fade out hurt flash
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		hurt_overlay.modulate.a = (_hurt_flash_timer / _hurt_flash_duration) * 0.55
		if _hurt_flash_timer <= 0.0:
			hurt_overlay.visible = false

	$SpringArm3D.rotation_degrees.x -= mouse_delta.y * look_sensitivity * delta
	$SpringArm3D.rotation_degrees.x = clamp($SpringArm3D.rotation_degrees.x, min_look_angle, max_look_angle)
	rotation_degrees.y -= mouse_delta.x * look_sensitivity * delta

	if $SpringArm3D.spring_length < 0.8:
		$Barbarian.hide()
	else:
		$Barbarian.show()

	mouse_delta = Vector2()
	window_activity()

func _physics_process(delta):
	if is_dead:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta)
		move_and_slide()
		return # Stop reading the rest of the movement code
	
	var height_boost = target_zoom * 0.3
	$SpringArm3D.spring_length = lerp($SpringArm3D.spring_length, target_zoom, 10.0 * delta)
	camera.position.y = lerp(camera.position.y, base_camera_y + height_boost, 10.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	var current_speed = move_speed
	if Input.is_action_pressed("sprint"):
		current_speed = run_speed

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if wall_jump_cooldown > 0.0:
		wall_jump_cooldown -= delta

	var is_climbing = false

	if $Barbarian/ClimbCheck.is_colliding() and wall_jump_cooldown <= 0.0:
		var hit_object = $Barbarian/ClimbCheck.get_collider()
		if hit_object is StaticBody3D:
			var hit_normal = $Barbarian/ClimbCheck.get_collision_normal()
			if hit_normal.y < 0.6 and hit_normal.y > -0.6:
				if Input.is_action_pressed("move_forward") or not is_on_floor():
					is_climbing = true

	if is_climbing:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force * 0.8
			var backward_dir = $Barbarian.global_transform.basis.z.normalized()
			velocity.x = backward_dir.x * (move_speed * 1.5)
			velocity.z = backward_dir.z * (move_speed * 1.5)
			wall_jump_cooldown = 0.3
			is_climbing = false
		else:
			velocity.y = -input_dir.y * climb_speed
			velocity.x = direction.x * (move_speed * 0.5)
			velocity.z = direction.z * (move_speed * 0.5)
	else:
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

	if is_climbing:
		if input_dir.y != 0:
			$AnimationPlayer.play("climb")
		else:
			$AnimationPlayer.play("jump_idle")
	elif not is_on_floor():
		if velocity.y > 0:
			$AnimationPlayer.play("jump_start")
		elif velocity.y < -3.0:
			$AnimationPlayer.play("jump_idle")
	elif direction:
		if Input.is_action_pressed("sprint"):
			$AnimationPlayer.play("running")
		else:
			$AnimationPlayer.play("walk")
	else:
		$AnimationPlayer.play("idle")
		
	# --- FALL DAMAGE TRACKING ---
	if not is_on_floor():
		# If the player is falling (negative Y velocity), track their highest speed
		if velocity.y < 0 and abs(velocity.y) > _max_downward_speed:
			_max_downward_speed = abs(velocity.y)
	else:
		# The player is on the floor. Did they just land from a fast fall?
		if _max_downward_speed > safe_fall_speed:
			# Calculate how much faster they were falling than the safe limit
			var excess_speed = _max_downward_speed - safe_fall_speed
			var damage = int(excess_speed * fall_damage_multiplier)
			
			if damage > 0:
				take_damage(damage)
				print("Player took fall damage: ", damage)
				
		# Always reset the downward speed once on the floor so they don't take damage again
		_max_downward_speed = 0.0
	# -----------------------------
	move_and_slide()

@rpc("call_local", "any_peer", "reliable")
func _go_to_main_menu_from_explorer():
	# THE FIX: Give the network 0.2 seconds to actually send the RPC packet across the internet!
	await get_tree().create_timer(0.2).timeout
	
	# Tear down the multiplayer peer on every machine before loading the menu
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.reset()
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")

func window_activity():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
