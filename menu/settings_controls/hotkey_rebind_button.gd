class_name HotKeyRebindButton
extends Control

@onready var label: Label = $HBoxContainer/Label as Label
@onready var button: Button = $HBoxContainer/Button as Button

@export var action_name : String = "move_left"

func _ready() -> void:
	set_process_unhandled_key_input(false)
	_set_action_name()
	_set_text_for_key()

func _set_action_name() -> void:
	label.text = "Unassigned" 

	match action_name:
		"move_left":
			label.text = "Move Left"
		"move_right":
			label.text = "Move Right"
		"jump":
			label.text = "Jump"

func _set_text_for_key() -> void:
	var action_events = InputMap.action_get_events(action_name)
	var action_event = action_events[0]
	var action_keycode = OS.get_keycode_string(action_event.physical_keycode)
	
	button.text = "%s" % action_keycode

func _on_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		button.text = "Press any key..."
		set_process_unhandled_key_input(toggled_on)
		
		for i in get_tree().get_nodes_in_group("hotkey_button"):
			if i.action_name != self.action_name:
				i.button.button_pressed = false
				i.set_process_unhandled_key_input(false)
			
	else:
		for i in get_tree().get_nodes_in_group("hotkey_button"):
			if i.action_name != self.action_name:
				i.set_process_unhandled_key_input(false)
		_set_text_for_key()

func _unhandled_key_input(event: InputEvent) -> void:
	_rebind_action_key(event)
	button.button_pressed = false
	
func _rebind_action_key(event) -> void:
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)
	
	set_process_unhandled_key_input(false)
	_set_text_for_key()
	_set_action_name()
