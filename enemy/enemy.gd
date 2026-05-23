extends CharacterBody3D

@export var move_speed: float = 15.0
@export var gravity: float = 50.0
@export var attack_range: float = 1.5
@export var damage_amount: int = 15

var target: Node3D = null
var is_attacking: bool = false
var _damage_dealt_this_swing: bool = false  # Prevents multiple hits per animation

@onready var anim_player = $AnimationPlayer

func _ready():
	$DetectionZone.body_entered.connect(_on_detection_zone_body_entered)
	$DetectionZone.body_exited.connect(_on_detection_zone_body_exited)

	# Connect animation_finished to know when the attack swing completes
	anim_player.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- CHASE LOGIC ---
	if target != null:
		var enemy_pos2d = Vector2(global_position.x, global_position.z)
		var target_pos2d = Vector2(target.global_position.x, target.global_position.z)
		var flat_distance = enemy_pos2d.distance_to(target_pos2d)
		
		var direction = global_position.direction_to(target.global_position)
		direction.y = 0 
		direction = direction.normalized()
		
		# 1. ROTATION
		if direction != Vector3.ZERO:
			var target_angle = atan2(direction.x, direction.z)
			$skeleton_mage.rotation.y = lerp_angle($skeleton_mage.rotation.y, target_angle, 10.0 * delta)

		# 2. CHASE OR ATTACK
		if flat_distance > attack_range:
			is_attacking = false
			_damage_dealt_this_swing = false
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			anim_player.play("enemy_run")
		else:
			velocity.x = 0
			velocity.z = 0
			if not is_attacking:
				is_attacking = true
				_damage_dealt_this_swing = false
				anim_player.play("enemy_attack")
	else:
		# --- IDLE LOGIC ---
		is_attacking = false
		_damage_dealt_this_swing = false
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		anim_player.play("enemy_idle")

	move_and_slide()

# Fires when any animation finishes
func _on_animation_finished(anim_name: StringName):
	if anim_name == "enemy_attack":
		# Deal damage once at the end of the swing
		if not _damage_dealt_this_swing and target != null and target.has_method("take_damage"):
			_damage_dealt_this_swing = true
			target.take_damage(damage_amount)

		# Allow the next swing to start
		is_attacking = false
		_damage_dealt_this_swing = false

# --- DETECTION AREA LOGIC ---
func _on_detection_zone_body_entered(body: Node3D):
	# Only chase the explorer (Scientist has no take_damage, don't target them)
	if body.is_in_group("explorer"):
		target = body
		print("Explorer spotted!")

func _on_detection_zone_body_exited(body: Node3D):
	if body == target:
		target = null
		is_attacking = false
		_damage_dealt_this_swing = false
		print("Explorer lost!")
