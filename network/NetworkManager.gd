extends Node

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1" # Localhost for testing
const MAX_PLAYERS = 2

# Dictionary to hold player data: { peer_id: {"role": "explorer" or "scientist"} }
var players = {}
var local_role = "explorer" # Default

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal server_disconnected
signal player_registered(peer_id)

func host_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		print("Cannot host: " + str(error))
		return
	
	multiplayer.multiplayer_peer = peer
	players[1] = {"role": local_role} # The host is always ID 1
	
	# Check if connected before connecting!
	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)
		
	if not multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.connect(_on_player_disconnected)

func join_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(DEFAULT_SERVER_IP, PORT)
	if error != OK:
		print("Cannot join: " + str(error))
		return
		
	multiplayer.multiplayer_peer = peer
	
	# Check if connected before connecting!
	if not multiplayer.connected_to_server.is_connected(_on_connected_ok):
		multiplayer.connected_to_server.connect(_on_connected_ok)
		
	if not multiplayer.connection_failed.is_connected(_on_connected_fail):
		multiplayer.connection_failed.connect(_on_connected_fail)
		
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_player_connected(id):
	print("Player joined: " + str(id))
	player_connected.emit(id)

func _on_player_disconnected(id):
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = {"role": local_role}
	# We deleted the RPC line from here!

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

# This RPC runs on the Host's machine when a client joins
@rpc("any_peer", "reliable")
func register_player(role):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = {"role": role}
	
	# Tell the Host's game world that a new player is ready to be spawned!
	if multiplayer.is_server():
		player_registered.emit(new_player_id)
