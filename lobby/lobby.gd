extends Control

@onready var host_btn = $HostButton
@onready var join_btn = $JoinButton
@onready var role_select = $RoleSelect

func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	role_select.item_selected.connect(_on_role_selected)
	multiplayer.connected_to_server.connect(load_main_scene)

func _on_role_selected(index):
	# Update the local role in our Autoload before connecting
	if index == 0:
		NetworkManager.local_role = "explorer"
	else:
		NetworkManager.local_role = "scientist"

func _on_host_pressed():
	NetworkManager.host_game()
	start_game()

func _on_join_pressed():
	NetworkManager.join_game()
	# Clients don't start the game themselves; they wait for the host's RPC.

# The Host calls this to transition scenes
func start_game():
	rpc("load_main_scene")

# This tells all connected machines to swap scenes
@rpc("call_local", "reliable")
func load_main_scene():
	get_tree().change_scene_to_file("res://main_scene.tscn")
