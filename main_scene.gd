extends Node3D

var explorer_scene = preload("res://players/explorer.tscn")
var scientist_scene = preload("res://players/scientist.tscn")

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
