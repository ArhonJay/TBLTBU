extends Node3D

var explorer_scene = preload("res://explorer.tscn")
var scientist_scene = preload("res://scientist.tscn")

func _ready():
	if multiplayer.is_server():
		# 1. The Host spawns themselves immediately
		spawn_player(1)
		# 2. The Host listens for any clients that arrive later
		NetworkManager.player_registered.connect(spawn_player)
	else:
		# 3. The Client has finally finished loading the 3D map!
		# NOW it is safe to ask the Server to spawn our character.
		NetworkManager.rpc_id(1, "register_player", NetworkManager.local_role)

func spawn_player(peer_id):
	var role = NetworkManager.players[peer_id]["role"]
	var current_player_node
	
	if role == "explorer":
		current_player_node = explorer_scene.instantiate()
		current_player_node.position = $SpawnPoints/ExplorerSpawn.global_position
	else:
		current_player_node = scientist_scene.instantiate()
		current_player_node.position = $SpawnPoints/ScientistSpawn.global_position
		
	current_player_node.name = str(peer_id)
	current_player_node.set_multiplayer_authority(peer_id)
	
	# THE FIX: Drop them into the dedicated folder!
	$Players.add_child(current_player_node)
