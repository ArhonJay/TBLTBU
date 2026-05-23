extends Node

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_PLAYERS = 2

var players = {}
var local_role = "explorer"

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal server_disconnected
signal player_registered(peer_id)

# --- RESET: Always call this before hosting or joining, and when returning to menu ---
func reset():
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()

func host_game():
	reset() # Clear any leftover peer from a previous session

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		print("Cannot host: " + str(error))
		return

	multiplayer.multiplayer_peer = peer
	players[1] = {"role": local_role}

	if not multiplayer.peer_connected.is_connected(_on_player_connected):
		multiplayer.peer_connected.connect(_on_player_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_player_disconnected):
		multiplayer.peer_disconnected.connect(_on_player_disconnected)

func join_game():
	reset() # Clear any leftover peer from a previous session

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(DEFAULT_SERVER_IP, PORT)
	if error != OK:
		print("Cannot join: " + str(error))
		return

	multiplayer.multiplayer_peer = peer

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

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

@rpc("any_peer", "reliable")
func register_player(role):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = {"role": role}
	if multiplayer.is_server():
		player_registered.emit(new_player_id)
