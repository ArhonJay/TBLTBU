extends CharacterBody3D

@export var safe_fall_speed: float = 100.0
@export var fall_damage_multiplier: float = 2.0
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

# --- STAMINA ---
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0   # per second while sprinting
@export var stamina_regen_rate: float = 12.0   # per second while not sprinting
@export var stamina_regen_delay: float = 1.5   # seconds before regen starts after stopping
var current_stamina: float = 100.0
var _stamina_regen_timer: float = 0.0
var _stamina_exhausted: bool = false           # true only when stamina hits exactly 0

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
		var stamina_ui = get_node_or_null("StaminaUI")
		if stamina_ui:
			stamina_ui.hide()
		var inv = get_node_or_null("InventoryUI")
		if inv:
			inv.hide()
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
	current_stamina = max_stamina
	_update_health_ui()
	_update_stamina_ui()

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
	current_health = min(current_health, max_health)
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

func _update_stamina_ui():
	var stamina_ui = get_node_or_null("StaminaUI")
	if stamina_ui and stamina_ui.has_method("update_stamina"):
		stamina_ui.update_stamina(current_stamina, max_stamina)

func _die():
	is_dead = true
	set_process_input(false)

	print("Explorer died! Playing animation...")
	await $AnimationPlayer.animation_finished

	set_physics_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Clear inventory on death so it starts fresh next game
	var inv = get_node_or_null("InventoryUI")
	if inv and inv.has_method("clear_all"):
		inv.clear_all()
	_show_game_over_all.rpc()

@rpc("call_local", "any_peer", "reliable")
func _show_game_over_all():
	if is_multiplayer_authority():
		var hud = get_node_or_null("HealthbarUI")
		if hud and hud.has_method("show_game_over"):
			hud.show_game_over()

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

	# --- STAMINA TICK ---
	var wants_sprint = Input.is_action_pressed("sprint")
	var can_sprint = not _stamina_exhausted

	if wants_sprint and can_sprint:
		# Draining
		current_stamina -= stamina_drain_rate * delta
		_stamina_regen_timer = stamina_regen_delay
		if current_stamina <= 0.0:
			current_stamina = 0.0
			_stamina_exhausted = true   # locked until any stamina regens in
		_update_stamina_ui()
	else:
		# Regen after delay
		if _stamina_regen_timer > 0.0:
			_stamina_regen_timer -= delta
		elif current_stamina < max_stamina:
			current_stamina += stamina_regen_rate * delta
			if current_stamina >= max_stamina:
				current_stamina = max_stamina
			# Unlock sprinting as soon as ANY stamina has regenerated (not full, just > 0)
			if _stamina_exhausted and current_stamina > 0.0:
				_stamina_exhausted = false
			_update_stamina_ui()

	# --- HURT FLASH ---
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
		return

	var height_boost = target_zoom * 0.3
	$SpringArm3D.spring_length = lerp($SpringArm3D.spring_length, target_zoom, 10.0 * delta)
	camera.position.y = lerp(camera.position.y, base_camera_y + height_boost, 10.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	# Sprint only allowed when stamina is not exhausted
	var current_speed = move_speed
	if Input.is_action_pressed("sprint") and not _stamina_exhausted:
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
		if Input.is_action_pressed("sprint") and not _stamina_exhausted:
			$AnimationPlayer.play("running")
		else:
			$AnimationPlayer.play("walk")
	else:
		$AnimationPlayer.play("idle")

	# --- FALL DAMAGE TRACKING ---
	if not is_on_floor():
		if velocity.y < 0 and abs(velocity.y) > _max_downward_speed:
			_max_downward_speed = abs(velocity.y)
	else:
		if _max_downward_speed > safe_fall_speed:
			var excess_speed = _max_downward_speed - safe_fall_speed
			var damage = int(excess_speed * fall_damage_multiplier)
			if damage > 0:
				take_damage(damage)
				print("Player took fall damage: ", damage)
		_max_downward_speed = 0.0

	move_and_slide()

@rpc("call_local", "any_peer", "reliable")
func _go_to_main_menu_from_explorer():
	await get_tree().create_timer(0.2).timeout
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
