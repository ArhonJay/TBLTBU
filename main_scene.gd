extends Node3D

var explorer_scene = preload("res://players/explorer.tscn")
var scientist_scene = preload("res://players/scientist.tscn")
var enemy_scene = preload("res://enemy/enemy.tscn") # Change this path if needed!

func _ready():
	if multiplayer.is_server():
		# 1. The Host spawns themselves immediately
		spawn_player(1)
		spawn_enemies()
		# 2. The Host listens for any clients that arrive later
		NetworkManager.start_world_timer(600)
		NetworkManager.player_registered.connect(spawn_player)
	else:
		# 3. The Client has finally finished loading the 3D map!
		# NOW it is safe to ask the Server to spawn our character.
		NetworkManager.rpc_id(1, "register_player", NetworkManager.local_role)

func spawn_player(peer_id):
	var role = NetworkManager.players[peer_id]["role"]
	
	# HARDCODE FOR TESTING: Force host to be explorer, clients to be scientist
	if peer_id == 1:
		role = "explorer"
	else:
		role = "scientist"
		
	var current_player_node
	
	# 2. Instantiate and set position based on our forced test roles
	if role == "explorer":
		current_player_node = explorer_scene.instantiate()
		current_player_node.position = $SpawnPoints/ExplorerSpawn.position
	else:
		current_player_node = scientist_scene.instantiate()
		current_player_node.position = $SpawnPoints/ScientistSpawn.position
		
	# 3. Set authority, name, and add to tree
	current_player_node.name = str(peer_id)
	current_player_node.set_multiplayer_authority(peer_id)
	$Players.add_child(current_player_node)

func spawn_enemies():
	var my_spawn = get_node("SpawnPoints/ExplorerSpawn")
	
	for i in range(15):
		var enemy = enemy_scene.instantiate()
		
		# THE FIX: Force a unique name so Godot doesn't auto-generate one!
		# Using the loop number 'i' and a random number ensures it is completely unique
		enemy.name = "SkeletonMage_" + str(i)
		
		var random_offset_x = randf_range(-200.0, 100.0)
		var random_offset_z = randf_range(-100.0, 200.0)
		
		enemy.position = my_spawn.global_position + Vector3(random_offset_x, 10.0, random_offset_z)
		
		# THE FIX: Add the enemy to the tracked folder, not the MainScene!
		$Enemies.add_child(enemy)
