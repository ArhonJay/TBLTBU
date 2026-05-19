extends StaticBody3D

@export var keypad_ui: CanvasLayer

# the four possible colors and their materials
enum ChestColor { BLUE, GREEN, RED, YELLOW }
enum ChestID { MED, SEC, ENG, RSH }

# Ledger Alpha (Red Book) PINs
const LEDGER_ALPHA = {
	"MED": "4091",
	"SEC": "8832",
	"ENG": "1150",
	"RSH": "7449"
}

# Ledger Omega (Blue Book) PINs
const LEDGER_OMEGA = {
	"MED": "2290",
	"SEC": "6114",
	"ENG": "9009",
	"RSH": "3351"
}

var chest_color: int
var chest_id: int
var chest_id_string: String
var correct_pin: String
var player_nearby := false
var ui_open := false
var is_solved := false
var prompt_label: Label3D

# track previous ledger used globally
static var last_ledger_used: String = ""

@onready var color_indicator: MeshInstance3D = $ColorIndicator
@onready var id_label: Label3D = $Label3D
@onready var display: Label
@onready var result_label: Label

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
	
	# connect keypad buttons
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
	
	# randomize chest
	_randomize_chest()

func _randomize_chest():
	chest_color = randi() % 4
	chest_id = randi() % 4
	
	match chest_id:
		ChestID.MED: chest_id_string = "MED"
		ChestID.SEC: chest_id_string = "SEC"
		ChestID.ENG: chest_id_string = "ENG"
		ChestID.RSH: chest_id_string = "RSH"
	
	id_label.text = chest_id_string
	
	# get the color
	var tint: Color
	match chest_color:
		ChestColor.BLUE:
			tint = Color(0.3, 0.5, 1.0)
			id_label.modulate = Color.CYAN
		ChestColor.GREEN:
			tint = Color(0.3, 1.0, 0.3)
			id_label.modulate = Color.GREEN
		ChestColor.RED:
			tint = Color(1.0, 0.3, 0.3)
			id_label.modulate = Color.RED
		ChestColor.YELLOW:
			tint = Color(1.0, 1.0, 0.3)
			id_label.modulate = Color.YELLOW
	
	# apply tint to ALL surfaces on the chest mesh
	var mesh_instance = $MeshInstance3D
	var surface_count = mesh_instance.get_surface_override_material_count()
	print("Surface count: ", surface_count)
	for i in range(surface_count):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tint
		mesh_instance.set_surface_override_material(i, mat)
	
	correct_pin = _determine_pin()
	print("DEBUG - Color: ", chest_color, " ID: ", chest_id_string, " Correct PIN: ", correct_pin)

func _determine_pin() -> String:
	var ledger: String
	
	match chest_color:
		ChestColor.BLUE:
			# use OPPOSITE of last ledger, default ALPHA if first
			if last_ledger_used == "":
				ledger = "ALPHA"
			elif last_ledger_used == "ALPHA":
				ledger = "OMEGA"
			else:
				ledger = "ALPHA"
		
		ChestColor.GREEN:
			# needs timer — defaulting to ALPHA for now
			ledger = "ALPHA"
			print("NOTE: Green chest needs timer logic — defaulting to ALPHA")
		
		ChestColor.RED:
			# check if ID tag contains a vowel
			var vowels = ["A", "E", "I", "O", "U"]
			var has_vowel = false
			for letter in chest_id_string:
				if letter.to_upper() in vowels:
					has_vowel = true
					break
			if has_vowel:
				ledger = "ALPHA"
			else:
				ledger = "OMEGA"
		
		ChestColor.YELLOW:
			# always OMEGA
			ledger = "OMEGA"
	
	# save for next chest
	last_ledger_used = ledger
	print("Using ledger: ", ledger)
	
	if ledger == "ALPHA":
		return LEDGER_ALPHA[chest_id_string]
	else:
		return LEDGER_OMEGA[chest_id_string]

var current_input := ""

func _on_number_pressed(number: String):
	if current_input.length() < 6:
		current_input += number
		display.text = current_input
		result_label.text = ""

func _on_backspace():
	if current_input.length() > 0:
		current_input = current_input.left(current_input.length() - 1)
		display.text = current_input if current_input.length() > 0 else "----"
		result_label.text = ""

func _on_enter():
	if current_input == correct_pin:
		result_label.text = "✓ CORRECT!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
		await get_tree().create_timer(1.0).timeout
		_solve_chest()
	else:
		result_label.text = "✗ WRONG PIN"
		result_label.add_theme_color_override("font_color", Color.RED)
		current_input = ""
		await get_tree().create_timer(1.5).timeout
		display.text = "----"
		result_label.text = ""

func _solve_chest():
	is_solved = true
	result_label.text = "✓ CHEST UNLOCKED!"
	result_label.add_theme_color_override("font_color", Color.GREEN)
	# keep the keypad open so player can see the message
	await get_tree().create_timer(2.0).timeout
	_close_keypad()

func _open_keypad():
	if is_solved:
		return
	ui_open = true
	current_input = ""
	display.text = "----"
	result_label.text = ""
	keypad_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_keypad():
	ui_open = false
	keypad_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = true
		prompt_label.visible = true


func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = false
		prompt_label.visible = false

		if ui_open:
			_close_keypad()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open:
			_open_keypad()
		elif ui_open:
			_close_keypad()
