extends StaticBody3D

@export var keypad_ui: CanvasLayer

const CORRECT_CODE = "1234"  # change this to your code later
var current_input := ""
var player_nearby := false
var ui_open := false
var is_solved := false

var display: Label
var result_label: Label
var prompt_label: Label3D

func _ready():
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)
	
	prompt_label = Label3D.new()
	prompt_label.text = "Press E to interact"
	prompt_label.position = Vector3(0, 1.5, 0.1)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 48
	prompt_label.outline_size = 8
	prompt_label.visible = false
	add_child(prompt_label)
	
	display = keypad_ui.get_node("Control/PanelContainer/VBoxContainer/Display")
	result_label = keypad_ui.get_node("Control/PanelContainer/VBoxContainer/ResultLabel")
	
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer/Btn1").pressed.connect(func(): _on_number_pressed("1"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer/Btn2").pressed.connect(func(): _on_number_pressed("2"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer/Btn3").pressed.connect(func(): _on_number_pressed("3"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer2/Btn4").pressed.connect(func(): _on_number_pressed("4"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer2/Btn5").pressed.connect(func(): _on_number_pressed("5"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer2/Btn6").pressed.connect(func(): _on_number_pressed("6"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer3/Btn7").pressed.connect(func(): _on_number_pressed("7"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer3/Btn8").pressed.connect(func(): _on_number_pressed("8"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer3/Btn9").pressed.connect(func(): _on_number_pressed("9"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer4/Btn0").pressed.connect(func(): _on_number_pressed("0"))
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer4/BtnBackspace").pressed.connect(_on_backspace)
	keypad_ui.get_node("Control/PanelContainer/VBoxContainer/HBoxContainer4/BtnEnter").pressed.connect(_on_enter)
	keypad_ui.get_node("Control/CloseButton").pressed.connect(_close_keypad)
	
	keypad_ui.visible = false


# Called by chest.gd when the chest is unlocked
func disable():
	is_solved = true
	set_process_unhandled_input(false)
	$InteractionZone.monitoring = false
	prompt_label.visible = false
	if ui_open:
		_close_keypad()


func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = false
		if ui_open:
			_close_keypad()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open and not is_solved:
			_open_keypad()
		elif ui_open:
			_close_keypad()

func _on_number_pressed(number: String):
	if current_input.length() < 8:
		current_input += number
		display.text = current_input
		result_label.text = ""

func _on_backspace():
	if current_input.length() > 0:
		current_input = current_input.left(current_input.length() - 1)
		display.text = current_input if current_input.length() > 0 else "----"
		result_label.text = ""

func _on_enter():
	if current_input == CORRECT_CODE:
		result_label.text = "✓ CORRECT!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "✗ INCORRECT"
		result_label.add_theme_color_override("font_color", Color.RED)
		current_input = ""
		await get_tree().create_timer(1.5).timeout
		display.text = "----"
		result_label.text = ""

func _open_keypad():
	ui_open = true
	current_input = ""
	display.text = "----"
	result_label.text = ""
	keypad_ui.visible = true
	prompt_label.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_keypad():
	ui_open = false
	keypad_ui.visible = false
	prompt_label.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
