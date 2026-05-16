class_name SettingsMenu
extends Control

@onready var back_button: Button = $MarginContainer/VBoxContainer/back_button

#signal back_options_menu

func _ready() -> void:
	if back_button:
		back_button.button_down.connect(_on_back_button_pressed)
	else:
		push_error("back_button not found!")
	set_process(false)

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	#back_options_menu.emit()
	#set_process(false)
