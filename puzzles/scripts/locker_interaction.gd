extends StaticBody3D

@export var keypad_ui: CanvasLayer

const EMPLOYEES := [
	{
		"name":        "Officer Vance",
		"description": "Security Dept.",
		"pin":         "8192",
		"photo_path":  "res://assets/employees/officer_vance.png"
	},
	{
		"name":        "Officer Miller",
		"description": "Security Dept.",
		"pin":         "0451",
		"photo_path":  "res://assets/employees/officer_miller.png"
	},
	{
		"name":        "Officer Briggs",
		"description": "Security Dept.",
		"pin":         "7734",
		"photo_path":  "res://assets/employees/officer_briggs.png"
	},
	{
		"name":        "Dr. Aris",
		"description": "Research & Science",
		"pin":         "3141",
		"photo_path":  "res://assets/employees/dr_aris.png"
	},
	{
		"name":        "Dr. Cobb",
		"description": "Research & Science",
		"pin":         "8008",
		"photo_path":  "res://assets/employees/dr_cobb.png"
	},
	{
		"name":        "Dr. Sterling",
		"description": "Research & Science",
		"pin":         "5926",
		"photo_path":  "res://assets/employees/dr_sterling.png"
	},
]

const OPEN_ANIM := "Locker_Door_003Action"

var correct_code := ""
var current_input := ""
var player_nearby := false
var ui_open := false
var is_unlocked := false

var display: Label
var result_label: Label
var prompt_label: Label3D
var employee_photo_node: TextureRect
var employee_name_label: Label
var employee_desc_label: Label
var anim_player: AnimationPlayer

const _BASE := "Control/CenterContainer/MainPanel/MarginContainer/HBoxContainer"
const _KP   := _BASE + "/KeypadPanel"
const _EP   := _BASE + "/EmployeePanel"


func _ready():
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)

	anim_player = _find_animation_player($LockerModel)
	if anim_player == null:
		push_warning("Locker: AnimationPlayer not found inside LockerModel.")
	else:
		anim_player.stop()

	prompt_label = Label3D.new()
	prompt_label.text = "Press E to interact"
	prompt_label.position = Vector3(0, 1.5, 0.1)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 48
	prompt_label.outline_size = 8
	prompt_label.visible = false
	add_child(prompt_label)

	display      = keypad_ui.get_node(_KP + "/Display")
	result_label = keypad_ui.get_node(_KP + "/ResultLabel")

	employee_photo_node = keypad_ui.get_node(_EP + "/EmployeePhoto")
	employee_name_label = keypad_ui.get_node(_EP + "/EmployeeName")
	employee_desc_label = keypad_ui.get_node(_EP + "/EmployeeDescription")

	keypad_ui.get_node(_KP + "/HBoxContainer/Btn1").pressed.connect(func(): _on_number_pressed("1"))
	keypad_ui.get_node(_KP + "/HBoxContainer/Btn2").pressed.connect(func(): _on_number_pressed("2"))
	keypad_ui.get_node(_KP + "/HBoxContainer/Btn3").pressed.connect(func(): _on_number_pressed("3"))
	keypad_ui.get_node(_KP + "/HBoxContainer2/Btn4").pressed.connect(func(): _on_number_pressed("4"))
	keypad_ui.get_node(_KP + "/HBoxContainer2/Btn5").pressed.connect(func(): _on_number_pressed("5"))
	keypad_ui.get_node(_KP + "/HBoxContainer2/Btn6").pressed.connect(func(): _on_number_pressed("6"))
	keypad_ui.get_node(_KP + "/HBoxContainer3/Btn7").pressed.connect(func(): _on_number_pressed("7"))
	keypad_ui.get_node(_KP + "/HBoxContainer3/Btn8").pressed.connect(func(): _on_number_pressed("8"))
	keypad_ui.get_node(_KP + "/HBoxContainer3/Btn9").pressed.connect(func(): _on_number_pressed("9"))
	keypad_ui.get_node(_KP + "/HBoxContainer4/Btn0").pressed.connect(func(): _on_number_pressed("0"))
	keypad_ui.get_node(_KP + "/HBoxContainer4/BtnBackspace").pressed.connect(_on_backspace)
	keypad_ui.get_node(_KP + "/HBoxContainer4/BtnEnter").pressed.connect(_on_enter)
	keypad_ui.get_node(_KP + "/CloseRow/CloseButton").pressed.connect(_close_keypad)

	keypad_ui.visible = false
	_assign_random_employee()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _assign_random_employee():
	var employee: Dictionary = EMPLOYEES[randi() % EMPLOYEES.size()]
	correct_code = employee["pin"]
	employee_name_label.text = employee["name"]
	employee_desc_label.text = employee["description"]
	var path: String = employee["photo_path"]
	if path != "" and ResourceLoader.exists(path):
		employee_photo_node.texture = load(path)
	else:
		employee_photo_node.texture = null


func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = true
		if not is_unlocked:
			if ObjectiveManager.get_phase() < 2:
				prompt_label.text = "Complete all objectives first"
			else:
				prompt_label.text = "Press E to interact"
			prompt_label.visible = true


func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = false
		prompt_label.visible = false
		if ui_open:
			_close_keypad()


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open and not is_unlocked:
			if ObjectiveManager.get_phase() < 2:
				return
			_open_keypad()
		elif ui_open:
			_close_keypad()


func _on_number_pressed(number: String):
	if current_input.length() < 4:
		current_input += number
		display.text = current_input
		result_label.text = ""


func _on_backspace():
	if current_input.length() > 0:
		current_input = current_input.left(current_input.length() - 1)
		display.text = current_input if current_input.length() > 0 else "----"
		result_label.text = ""


func _on_enter():
	if current_input == correct_code:
		is_unlocked = true
		result_label.text = "✓ UNLOCKED"
		result_label.add_theme_color_override("font_color", Color.GREEN)
		await get_tree().create_timer(1.5).timeout
		_close_keypad()
		_on_locker_unlocked()
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


func _on_locker_unlocked():
	prompt_label.text = "Unlocked"

	if anim_player and anim_player.has_animation(OPEN_ANIM):
		anim_player.play(OPEN_ANIM)
	else:
		push_warning("Locker: animation '%s' not found. Available: %s" % [
			OPEN_ANIM,
			str(anim_player.get_animation_list()) if anim_player else "no AnimationPlayer"
		])

	# ── Notify objective tracker — this completes the game ────────────────────
	ObjectiveManager.register_locker_solved()
