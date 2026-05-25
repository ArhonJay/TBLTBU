extends Node3D

@export var simonref_scene: PackedScene
@export var spawn_count: int = 10
@export var spawn_area_size: Vector2 = Vector2(40.0, 40.0)

func _ready():
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
		
	# Wait for the physics engine to fully load the terrain collision
	await get_tree().physics_frame 
	_simonref_chest()

func _simonref_chest():
	var space_state = get_world_3d().direct_space_state
	
	var successfully_spawned = 0
	var safety_breaker = 0 # Prevents the game from freezing if it can't find ground
	var max_attempts = spawn_count * 10 
	
	while successfully_spawned < spawn_count and safety_breaker < max_attempts:
		safety_breaker += 1
		
		var random_x = randf_range(-spawn_area_size.x / 2.0, spawn_area_size.x / 2.0)
		var random_z = randf_range(-spawn_area_size.y / 2.0, spawn_area_size.y / 2.0)
		
		# 1. Start WAY higher in the sky (1000 instead of 100) to clear tall mountains
		var ray_start = Vector3(global_position.x + random_x, 1000.0, global_position.z + random_z)
		# 2. Aim WAY lower (-1000 instead of -100)
		var ray_end = Vector3(global_position.x + random_x, -1000.0, global_position.z + random_z)
		
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		
		# Optional: If your water has collision and mushrooms are spawning on water, 
		# you need to set the query's collision mask to ONLY hit your terrain layer.
		# query.collision_mask = 1 # Uncomment and change '1' to your terrain's physics layer
		
		var result = space_state.intersect_ray(query)
		
		# 3. ONLY spawn if the ray actually hit something
		if result:
			# 4. Optional water check: If your water is at Y=0, don't spawn below it
			if result.position.y > 0.5: 
				var mushroom = simonref_scene.instantiate()
				mushroom.name = "MushroomPatch_" + str(successfully_spawned)
				
				# FIRST: Add the child to the scene tree
				add_child(mushroom, true)
				
				# SECOND: Set the GLOBAL position so it ignores the Spawner's height
				mushroom.global_position = result.position
				
				successfully_spawned += 1 # Success! Count it.
