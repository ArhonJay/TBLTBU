extends CharacterBody3D

# --- TORNADO COMBO STATE ---
var trapped_tornado: Node3D = null
var is_thrown: bool = false
var _tornado_angle: float = 0.0
var _target_spins: int = 0
var _current_spin_progress: float = 0.0
var _pending_tornado_damage: int = 0
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
@export var stamina_drain_rate: float = 25.0
@export var stamina_regen_rate: float = 12.0
@export var stamina_regen_delay: float = 1.5
var current_stamina: float = 100.0
var _stamina_regen_timer: float = 0.0
var _stamina_exhausted: bool = false

# --- OBJECTIVE LIST & END SEQUENCE ---
const OBJECTIVE_LIST_SCENE := preload("res://puzzles/scenes/ObjectiveList.tscn")
const GAME_END_SEQUENCE_SCENE := preload("res://puzzles/scenes/GameEndSequence.tscn")

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

	# ── Spawn the ObjectiveList HUD as a child of this explorer ───────────────
	var obj_list = OBJECTIVE_LIST_SCENE.instantiate()
	obj_list.name = "ObjectiveList"
	add_child(obj_list)

	# ── Spawn GameEndSequence on the scene root (shared by both peers) ───────
	if get_tree().current_scene.get_node_or_null("GameEndSequence") == null:
		var end_seq = GAME_END_SEQUENCE_SCENE.instantiate()
		end_seq.name = "GameEndSequence"
		get_tree().current_scene.add_child(end_seq)

	# ── Start the mission timer ───────────────────────────────────────────────
	ObjectiveManager.start_timer()

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

func catch_in_tornado(tornado_node: Node3D):
	if is_dead or trapped_tornado != null or is_thrown:
		return

	trapped_tornado = tornado_node
	_target_spins = randi_range(1, 6)
	_current_spin_progress = 0.0
	_pending_tornado_damage = _target_spins * 5

	print("Explorer caught! Spinning ", _target_spins, " times. Pending Damage: ", _pending_tornado_damage)

	var offset = global_position - tornado_node.global_position
	_tornado_angle = atan2(offset.z, offset.x)

func _throw_from_tornado():
	print("Explorer was spat out! Brace for impact...")
	is_thrown = true

	var knockback_dir = (global_position - trapped_tornado.global_position).normalized()
	trapped_tornado = null

	velocity.x = knockback_dir.x * 60.0
	velocity.z = knockback_dir.z * 60.0
	velocity.y = 45.0

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
	var inv = get_node_or_null("InventoryUI")
	if inv and inv.has_method("clear_all"):
		inv.clear_all()
	_show_game_over_all.rpc()

func _on_timeout_death():
	if not is_dead:
		print("Time is up! Explorer died to the timer.")
		take_damage(999)

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

	# Close any open manual reader with E / interact
	if event.is_action_pressed("interact") or event.is_action_pressed("use_item"):
		for child in get_children():
			if child is CanvasLayer and child.get_meta("manual_reader", false):
				child.queue_free()
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				return  # consume the input — don't also open/use

	if event is InputEventMouseMotion:
		mouse_delta = event.relative

	if event.is_action_pressed("use_item"):
		use_item()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom -= zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom += zoom_step
		target_zoom = clamp(target_zoom, min_zoom, max_zoom)

func _process(delta):
	if is_dead:
		return

	var wants_sprint = Input.is_action_pressed("sprint")
	var can_sprint = not _stamina_exhausted

	if wants_sprint and can_sprint:
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
	# 1. DEAD PHYSICS
	if is_dead:
		trapped_tornado = null
		is_thrown = false
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta)
		move_and_slide()
		return

	# 2. TRAPPED PHYSICS
	if trapped_tornado != null:
		var spin_speed = 6.0
		var angle_step = spin_speed * delta

		_tornado_angle += angle_step
		_current_spin_progress += angle_step

		if _current_spin_progress >= (_target_spins * TAU):
			_throw_from_tornado()
			return

		var spin_radius = 2.0
		var target_x = trapped_tornado.global_position.x + cos(_tornado_angle) * spin_radius
		var target_z = trapped_tornado.global_position.z + sin(_tornado_angle) * spin_radius
		var target_y = trapped_tornado.global_position.y + 4.0

		velocity = (Vector3(target_x, target_y, target_z) - global_position) * 8.0

		$Barbarian.rotation.y += 15.0 * delta
		$AnimationPlayer.play("jump_start")
		move_and_slide()
		return

	# 3. THROWN PHYSICS
	if is_thrown:
		velocity.y -= gravity * delta
		$Barbarian.rotation.y += 20.0 * delta

		if is_on_floor():
			is_thrown = false
			print("Explorer landed from the throw!")

			if _pending_tornado_damage > 0:
				take_damage(_pending_tornado_damage)
				_pending_tornado_damage = 0

		if velocity.y < 0 and abs(velocity.y) > _max_downward_speed:
			_max_downward_speed = abs(velocity.y)

		move_and_slide()
		return

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
func _go_to_main_menu():
	await get_tree().create_timer(0.2).timeout
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.reset()
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")

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
			_show_use_popup("+%d HP" % amount, Color(0.20, 0.85, 0.35, 1.0))
		"energy_drink":
			var restore : float = item.get("stamina_restore", 50.0)
			current_stamina = min(current_stamina + restore, max_stamina)
			if current_stamina > 0.0:
				_stamina_exhausted = false
			_stamina_regen_timer = 0.0
			_update_stamina_ui()
			inv.remove_selected_item()
			print("Used Energy Drink — restored %.0f stamina." % restore)
			_show_use_popup("+%d STA" % int(restore), Color(0.25, 0.75, 1.0, 1.0))
		"potion_manual", "radio_manual":
			var manual_path := "res://assets/manual/" + item_id + ".png"
			var manual_tex: Texture2D = null
			if ResourceLoader.exists(manual_path):
				manual_tex = load(manual_path)
			else:
				push_warning("Manual not found: " + manual_path)
			_show_manual_reader(item_id, item.get("name", "Manual"), manual_tex)
		_:
			print("No use action defined for item: ", item_id)


# ── Item-use feedback popup ────────────────────────────────────────────────────
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


# ── Manual reader modal ───────────────────────────────────────────────────────
func _show_manual_reader(item_id: String, manual_name: String, tex) -> void:
	var popup_name := "_ManualReader_" + item_id
	var old := get_node_or_null(popup_name)
	if old:
		old.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	var layer := CanvasLayer.new()
	layer.name  = popup_name
	layer.layer = 15
	layer.set_meta("manual_reader", true)
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(overlay)

	var card := PanelContainer.new()
	var ps   := StyleBoxFlat.new()
	ps.bg_color              = Color(0.07, 0.06, 0.04, 0.98)
	ps.set_corner_radius_all(12)
	ps.border_width_top    = 2; ps.border_width_bottom = 2
	ps.border_width_left   = 2; ps.border_width_right  = 2
	ps.border_color        = Color(0.75, 0.60, 0.15, 1.0)
	ps.content_margin_top    = 20.0; ps.content_margin_bottom = 16.0
	ps.content_margin_left   = 24.0; ps.content_margin_right  = 24.0
	card.add_theme_stylebox_override("panel", ps)
	card.anchor_left   = 0.5; card.anchor_right  = 0.5
	card.anchor_top    = 0.5; card.anchor_bottom = 0.5
	card.offset_left   = -340.0; card.offset_right  = 340.0
	card.offset_top    = -420.0; card.offset_bottom = 420.0
	card.mouse_filter  = Control.MOUSE_FILTER_STOP
	root.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 1)
	hdr.add_child(title_col)

	var eyebrow := Label.new()
	eyebrow.text = "REFERENCE MANUAL"
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", Color(0.75, 0.60, 0.15, 0.85))
	title_col.add_child(eyebrow)

	var title_lbl := Label.new()
	title_lbl.text = manual_name
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.82, 1.0))
	title_col.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.add_theme_font_size_override("font_size", 16)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.20, 0.10, 0.06, 1.0)
	cs.set_corner_radius_all(6)
	cs.border_width_top = 1; cs.border_width_bottom = 1
	cs.border_width_left = 1; cs.border_width_right = 1
	cs.border_color = Color(0.60, 0.45, 0.10, 0.8)
	close_btn.add_theme_stylebox_override("normal", cs)
	close_btn.pressed.connect(func():
		layer.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)
	hdr.add_child(close_btn)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.75, 0.60, 0.15, 0.4))
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	if tex != null:
		var img_rect := TextureRect.new()
		img_rect.texture      = tex
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		img_rect.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		scroll.add_child(img_rect)
	else:
		var missing := Label.new()
		missing.text = "[Manual image not found]\nExpected: res://assets/manual/" + item_id + ".png"
		missing.add_theme_color_override("font_color", Color(0.80, 0.40, 0.30, 1.0))
		missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD
		scroll.add_child(missing)

	var hint := Label.new()
	hint.text = "Press E or click ✕ to close"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.50, 0.48, 0.44, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			layer.queue_free()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)

	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.18)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func window_activity():
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
