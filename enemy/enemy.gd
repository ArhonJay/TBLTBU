extends CharacterBody3D

@export var move_speed: float = 15.0
@export var gravity: float = 50.0
@export var attack_range: float = 1.5

var target: Node3D = null
@onready var anim_player = $AnimationPlayer

func _ready():
	# Connect the detection zone signals via code
	$DetectionZone.body_entered.connect(_on_detection_zone_body_entered)
	$DetectionZone.body_exited.connect(_on_detection_zone_body_exited)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- CHASE LOGIC ---
	if target != null:
		# THE FIX: Calculate a flat 2D distance ignoring slopes/height
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
		if flat_distance > attack_range: # Use flat_distance here!
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			anim_player.play("enemy_run") 
			
		else:
			velocity.x = 0
			velocity.z = 0
			anim_player.play("enemy_attack")
	else:
		# --- IDLE LOGIC ---
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		anim_player.play("enemy_idle") 

	move_and_slide()

# --- DETECTION AREA LOGIC ---
func _on_detection_zone_body_entered(body: Node3D):
	# Only lock on if the body has the "explorer" group tag!
	if body.is_in_group("explorer"):
		target = body
		print("Explorer spotted!")

func _on_detection_zone_body_exited(body: Node3D):
	if body == target:
		target = null
		print("Explorer lost!")
