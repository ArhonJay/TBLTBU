extends CharacterBody3D

@export var move_speed: float = 20.0
@export var run_speed: float = 50.0
@export var jump_force: float = 20.0
@export var gravity: float = 50.0

const MOUSE_SENSITIVITY = 0.002
@export var look_sensitivity: float = 2.0
var min_look_angle: float = -90.0
var max_look_angle: float = 90.0
var mouse_delta: Vector2 = Vector2()
@onready var camera = $SpringArm3D/Camera
@onready var hand = get_node("SpringArm3D/Camera/Hand")

# --- STAMINA ---
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0   # per second while sprinting
@export var stamina_regen_rate: float = 12.0   # per second while not sprinting
@export var stamina_regen_delay: float = 1.5   # seconds before regen starts after stopping
var current_stamina: float = 100.0
var _stamina_regen_timer: float = 0.0
var _stamina_exhausted: bool = false           # true only when stamina hits exactly 0

var target_zoom: float = 0.0
var min_zoom: float = 0.0
var max_zoom: float = 4.0
var zoom_step: float = 0.4
var base_camera_y: float

# --- GAME OVER OVERLAY (built in code, no extra scene needed) ---
var _game_over_overlay: CanvasLayer = null

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not is_multiplayer_authority():
		camera.current = false
		set_physics_process(false)
		set_process(false)
		set_process_input(false)
		return

	add_to_group("scientist")
	camera.current = true
	$SpringArm3D.add_excluded_object(get_rid())

	base_camera_y = camera.position.y
	target_zoom = camera.position.z

	$Mage.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var spawn_point = get_tree().current_scene.get_node_or_null("SpawnPoints/ScientistSpawn")
	if spawn_point != null:
		global_position = spawn_point.global_position

	_build_game_over_overlay()

	current_stamina = max_stamina
	_update_stamina_ui()
	
func _update_stamina_ui():
	var stamina_ui = get_node_or_null("StaminaUI")
	if stamina_ui and stamina_ui.has_method("update_stamina"):
		stamina_ui.update_stamina(current_stamina, max_stamina)

# --- BUILD GAME OVER OVERLAY IN CODE ---
func _build_game_over_overlay():
	_game_over_overlay = CanvasLayer.new()
	_game_over_overlay.layer = 10
	add_child(_game_over_overlay)

	# Dark full-screen dimmer
	var dimmer = ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.0)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.add_child(dimmer)

	# Centered panel
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.04, 0.06, 0.95)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.7, 0.1, 0.1, 1.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -150.0
	panel.offset_bottom = 150.0
	_game_over_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Spacer top
	var spacer_top = Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer_top)

	# Skull icon label
	var skull = Label.new()
	skull.text = "💀"
	skull.add_theme_font_size_override("font_size", 52)
	skull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(skull)

	# GAME OVER title
	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.18, 0.18, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "The Explorer has fallen..."
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Spacer mid
	var spacer_mid = Control.new()
	spacer_mid.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer_mid)

	# Back to Main Menu button
	var btn = Button.new()
	btn.text = "  Back to Main Menu  "
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(0, 50)
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.6, 0.08, 0.08, 1.0)
	btn_normal.corner_radius_top_left = 8
	btn_normal.corner_radius_top_right = 8
	btn_normal.corner_radius_bottom_left = 8
	btn_normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", btn_normal)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.85, 0.15, 0.15, 1.0)
	btn_hover.corner_radius_top_left = 8
	btn_hover.corner_radius_top_right = 8
	btn_hover.corner_radius_bottom_left = 8
	btn_hover.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.pressed.connect(_on_back_to_menu_pressed)
	vbox.add_child(btn)

	# Spacer bottom
	var spacer_bot = Control.new()
	spacer_bot.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer_bot)

	_game_over_overlay.visible = false

# Called by explorer.gd's RPC when explorer dies
func show_game_over_local():
	if not is_multiplayer_authority():
		return
	set_physics_process(false)
	set_process_input(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _game_over_overlay:
		_game_over_overlay.visible = true

func _on_back_to_menu_pressed():
	# Send ALL players back to main menu via RPC
	_go_to_main_menu.rpc()

@rpc("call_local", "any_peer", "reliable")
func _go_to_main_menu():
	# THE FIX: Give the network 0.2 seconds to actually send the RPC packet across the internet!
	await get_tree().create_timer(0.2).timeout
	
	# Tear down the multiplayer peer on every machine before loading the menu
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.reset()
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")

func _input(event):
	if event is InputEventMouseMotion:
		mouse_delta = event.relative

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += zoom_step
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)

func _process(delta):
	$SpringArm3D.rotation_degrees.x -= mouse_delta.y * look_sensitivity * delta
	$SpringArm3D.rotation_degrees.x = clamp($SpringArm3D.rotation_degrees.x, min_look_angle, max_look_angle)
	rotation_degrees.y -= mouse_delta.x * look_sensitivity * delta

	if $SpringArm3D.spring_length < 0.8:
		$Mage.hide()
	else:
		$Mage.show()

	mouse_delta = Vector2()
	window_activity()

		
func _physics_process(delta):
	# --- STAMINA TICK ---
	var wants_sprint = Input.is_action_pressed("sprint")
	if wants_sprint and not _stamina_exhausted:
		current_stamina -= stamina_drain_rate * delta
		_stamina_regen_timer = stamina_regen_delay
		if current_stamina <= 0.0:
			current_stamina = 0.0
			_stamina_exhausted = true
		_update_stamina_ui()
	else:
		if _stamina_regen_timer > 0.0:
			_stamina_regen_timer -= delta
		elif current_stamina < max_stamina:
			current_stamina += stamina_regen_rate * delta
			if current_stamina >= max_stamina:
				current_stamina = max_stamina
			if _stamina_exhausted and current_stamina > 0.0:
				_stamina_exhausted = false
			_update_stamina_ui()

	var height_boost = target_zoom * 0.3
	$SpringArm3D.spring_length = lerp($SpringArm3D.spring_length, target_zoom, 10.0 * delta)
	camera.position.y = lerp(camera.position.y, base_camera_y + height_boost, 10.0 * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	var current_speed = move_speed
	if Input.is_action_pressed("sprint") and not _stamina_exhausted:
		current_speed = run_speed

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		var target_angle = atan2(-input_dir.x, -input_dir.y) + PI
		$Mage.rotation.y = lerp_angle($Mage.rotation.y, target_angle, 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	if not is_on_floor():
		if velocity.y > 0:
			$AnimationPlayer.play("jump_start")
		else:
			$AnimationPlayer.play("jump_idle")
	elif direction:
		if Input.is_action_pressed("sprint") and not _stamina_exhausted:
			$AnimationPlayer.play("running")
		else:
			$AnimationPlayer.play("walk")
	else:
		$AnimationPlayer.play("idle")

	move_and_slide()

func window_activity():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
