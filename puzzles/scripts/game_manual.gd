extends StaticBody3D
# game_manual.gd
# Drop the GameManual scene into any 3D scene.
# Works with scientist.gd's set_nearby_interactable / clear_nearby_interactable
# pattern — no separate input handling needed here.

@export var prompt_text: String = "[E] Read Manual"

@onready var prompt_label: Label3D    = $Label3D
@onready var manual_ui:   CanvasLayer = $GameManualUI

var _current_player: Node3D = null


func _ready() -> void:
	prompt_label.text = prompt_text
	prompt_label.hide()
	manual_ui.hide()

	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)


# Called by scientist.gd when the player presses E
func interact() -> void:
	_toggle_manual()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_current_player = body
		prompt_label.show()
		# Tell the scientist it can interact with us
		if body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(self)


func _on_body_exited(body: Node3D) -> void:
	if body == _current_player:
		prompt_label.hide()
		# Close if open
		if manual_ui.visible:
			manual_ui.hide()
			_release_mouse()
		# Tell the scientist we're no longer nearby
		if body.has_method("clear_nearby_interactable"):
			body.clear_nearby_interactable(self)
		_current_player = null


func _toggle_manual() -> void:
	if manual_ui.visible:
		manual_ui.hide()
		_release_mouse()
	else:
		manual_ui.show()
		_capture_mouse()


func _capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
