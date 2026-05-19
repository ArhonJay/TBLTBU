extends StaticBody3D

@export var manual_ui: CanvasLayer

var player_nearby := false
var ui_open := false
var prompt_label: Label3D


func _ready():

	print("ManualPaper ready!")
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)
	manual_ui.get_node("Control/CloseButton").pressed.connect(_close_manual)
	manual_ui.visible = false
	
	prompt_label = Label3D.new()
	prompt_label.text = "Press E to interact"
	prompt_label.position = Vector3(0, 1.5, 0.1)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 48
	prompt_label.outline_size = 8
	prompt_label.visible = false
	add_child(prompt_label)
	

func _on_body_entered(body: Node3D):
	print("Body entered: ", body.name)
	if body.is_in_group("player"):
		print("Player detected!")
		player_nearby = true
		prompt_label.visible = true


func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = false
		prompt_label.visible = false
		if ui_open:
			_close_manual()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		print("E pressed! player_nearby = ", player_nearby)
		if player_nearby and not ui_open:
			_open_manual()
		elif ui_open:
			_close_manual()

func _open_manual():
	ui_open = true
	manual_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_manual():
	ui_open = false
	manual_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
