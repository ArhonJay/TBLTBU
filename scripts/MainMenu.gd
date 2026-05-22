class_name MainMenu
extends Node2D

@onready var start_button = $ButtonManager/Start as Button
@onready var join_button = $ButtonManager/Join as Button
@onready var settings_button = $ButtonManager/Settings as Button
@onready var quit_button = $ButtonManager/Quit as Button
@onready var credits_button = $ButtonManager/Credits as Button

@onready var settings_menu: SettingsMenu = $SettingsMenu as SettingsMenu
@onready var margin_container: MarginContainer = $MarginContainer as MarginContainer

func _ready():
	MusicManager.play_music(preload("res://assets/music/Time Flows Ever Onward.mp3"))
	multiplayer.connected_to_server.connect(load_main_scene)

func _on_start_pressed() -> void:
	NetworkManager.host_game()
	start_game()

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")
	print("Load settings menu")
	#margin_container.visible = false
	#settings_menu.set_process(false)
	#settings_menu.visible = true

func _on_inventory_pressed() -> void:
	NetworkManager.join_game()
	# Clients don't start the game themselves; they wait for the host's RPC.

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/credits.tscn")

func _on_back_button_pressed() -> void:
	margin_container.visible = true
	settings_menu.visible = false

func handle_connecting_signals() -> void:
	start_button.button_down.connect(_on_start_pressed)
	join_button.button_down.connect(_on_inventory_pressed)
	settings_button.button_down.connect(_on_settings_pressed)
	quit_button.button_down.connect(_on_quit_pressed)
	credits_button.button_down.connect(_on_credits_pressed)
	settings_menu.back_options_menu.connect(_on_back_button_pressed)
	
# The Host calls this to transition scenes
func start_game():
	rpc("load_main_scene")

# This tells all connected machines to swap scenes
@rpc("call_local", "reliable")
func load_main_scene():
	get_tree().change_scene_to_file("res://main_scene.tscn")
