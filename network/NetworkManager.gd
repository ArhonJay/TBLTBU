extends Node

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_PLAYERS = 2

var players = {}
var local_role = "explorer"	

# --- NEW TIMER VARIABLES ---
var time_left: int = 0
var is_timer_running: bool = false
var server_timer: Timer

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal server_disconnected
signal player_registered(peer_id)

# --- NEW SIGNALS ---
signal time_updated(new_time)
signal match_ended_time_out

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
	print("Host disconnected. Returning to main menu...")
	
	# 1. Reset the multiplayer peer so it doesn't stay in a zombie state
	reset() 
	
	# 2. Give the player their mouse back
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 3. Load the main menu
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")

@rpc("any_peer", "reliable")
func register_player(role):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = {"role": role}
	if multiplayer.is_server():
		player_registered.emit(new_player_id)
		
# ==========================================
# TIMER LOGIC
# ==========================================

# Call this function ONLY on the server when the actual level loads/starts
func start_world_timer(seconds: int):
	print("SERVER IS ATTEMPTING TO START TIMER!") # <--- ADD THIS LINE
	if not multiplayer.is_server(): 
		return # Clients cannot start the timer

	time_left = seconds
	is_timer_running = true

	# Create the timer node if it doesn't exist yet
	if server_timer == null:
		server_timer = Timer.new()
		server_timer.wait_time = 1.0 # Tick every 1 second
		server_timer.autostart = false
		server_timer.timeout.connect(_on_server_timer_tick)
		add_child(server_timer)

	server_timer.start()
	
	# Force an immediate sync so clients see the starting time instantly
	sync_time_to_clients.rpc(time_left) 

func _on_server_timer_tick():
	if not multiplayer.is_server(): return

	time_left -= 1
	sync_time_to_clients.rpc(time_left) # Broadcast new time every second

	if time_left <= 0:
		server_timer.stop()
		is_timer_running = false
		trigger_time_out_death.rpc() # Broadcast game over

# --- RPCs (Remote Procedure Calls) ---

# "authority" means only the server can call this on the clients.
# "call_local" means the server also runs this locally on its own instance.
@rpc("authority", "call_local", "reliable")
func sync_time_to_clients(current_time: int):
	time_left = current_time
	time_updated.emit(time_left) # The UI will listen to this

@rpc("authority", "call_local", "reliable")
func trigger_time_out_death():
	print("Time is up! Instant death.")
	match_ended_time_out.emit()
	# Your player scripts or main game manager should listen to this signal 
	# to kill the players and show the Game Over screen.

# Call this on the server to add or subtract time from the world timer.
# Pass a positive value to add time (reward), negative to subtract (penalty).
func adjust_world_timer(delta: int):
	if not multiplayer.is_server():
		return
	if not is_timer_running:
		return

	time_left = max(0, time_left + delta)
	sync_time_to_clients.rpc(time_left)

	if time_left <= 0:
		server_timer.stop()
		is_timer_running = false
		trigger_time_out_death.rpc()
