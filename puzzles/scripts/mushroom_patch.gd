extends StaticBody3D

@export var mushroom_ui: CanvasLayer
var current_player: Node3D = null

# Mushroom data updated from Defusal Manual v.1 - Cavern Mycology
const MUSHROOM_DATA = {
	"Glowing Blue": {
		"appearance": "Glowing Blue Mushroom (Bioluminescent)",
		"color": Color(0.3, 0.5, 1.0),
		"smells": {
			"Sweet Fruit": {
				"action": "EAT",
				"name": "Lunar Cap",
				"effect": "Restores health",
				"heal": 50.0,
				"damage": 0.0
			},
			"Burnt Hair": {
				"action": "LEAVE",
				"name": "Static Spore",
				"effect": "Highly toxic!",
				"heal": 0.0,
				"damage": 40.0
			}
		}
	},
	"Red Spotted": {
		"appearance": "Red Spotted Mushroom (Crimson Cap)",
		"color": Color(1.0, 0.2, 0.2),
		"smells": {
			"Fresh Dirt / Earthy": {
				"action": "EAT",
				"name": "Blood Truffle",
				"effect": "Restores health",
				"heal": 25.0,
				"damage": 0.0
			},
			"Rotten Eggs / Sulfur": {
				"action": "LEAVE",
				"name": "Magma Cap",
				"effect": "Highly toxic!",
				"heal": 0.0,
				"damage": 40.0
			}
		}
	},
	"Pale Fleshy": {
		"appearance": "Pale Fleshy Mushroom (Ghost Shroom)",
		"color": Color(0.9, 0.9, 0.85),
		"smells": {
			"Sweet Fruit": {
				"action": "LEAVE",
				"name": "Corpse Trap",
				"effect": "Causes instant paralysis!",
				"heal": 0.0,
				"damage": 40.0
			},
			"Rotten Eggs / Sulfur": {
				"action": "EAT",
				"name": "Sulfur Sponge",
				"effect": "Restores health",
				"heal": 75.0,
				"damage": 0.0
			}
		}
	}
}

var mushroom_type: String
var current_smell: String
var current_data: Dictionary
var player_nearby := false
var ui_open := false
var already_picked := false

var prompt_label: Label3D

# UI node refs (cached once)
var btn_eat: Button
var btn_leave: Button
var btn_close: Button
var appearance_label: Label
var smell_label: Label
var result_label: Label

func _ready():
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)

	# Press E prompt
	prompt_label = Label3D.new()
	prompt_label.text = "Press E to interact"
	prompt_label.position = Vector3(0, 1.5, 0)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 48
	prompt_label.outline_size = 8
	prompt_label.visible = false
	add_child(prompt_label)

	# Cache UI node refs
	var vbox = mushroom_ui.get_node("Control/PanelContainer/VBoxContainer")
	appearance_label = vbox.get_node("AppearanceLabel")
	smell_label      = vbox.get_node("SmellLabel")
	result_label     = vbox.get_node("ResultLabel")
	btn_eat          = vbox.get_node("ButtonRow/BtnEat")
	btn_leave        = vbox.get_node("ButtonRow/BtnLeave")
	btn_close        = mushroom_ui.get_node("Control/CloseButton")

	mushroom_ui.visible = false
	_randomize_mushroom()

func _randomize_mushroom():
	var types = MUSHROOM_DATA.keys()
	mushroom_type = types[randi() % types.size()]
	var type_data = MUSHROOM_DATA[mushroom_type]

	var smells = type_data.smells.keys()
	current_smell = smells[randi() % smells.size()]
	current_data = type_data.smells[current_smell]

	_apply_color(type_data.color)

func _apply_color(color: Color):
	for child in get_children():
		_tint_mesh(child, color)

func _tint_mesh(node: Node, color: Color):
	if node is MeshInstance3D:
		var surface_count = node.get_surface_override_material_count()
		for i in range(surface_count):
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			node.set_surface_override_material(i, mat)
	for child in node.get_children():
		_tint_mesh(child, color)

func _open_ui():
	if already_picked:
		return
	ui_open = true

	var type_data = MUSHROOM_DATA[mushroom_type]
	appearance_label.text = "Appearance: " + type_data.appearance
	smell_label.text = "🌿 Smells like: " + current_smell + "..."
	result_label.text = ""

	# Disconnect any previous mushroom's handlers before connecting this one.
	# This ensures only THIS mushroom instance responds to button presses.
	for c in btn_eat.pressed.get_connections():
		btn_eat.pressed.disconnect(c.callable)
	for c in btn_leave.pressed.get_connections():
		btn_leave.pressed.disconnect(c.callable)
	for c in btn_close.pressed.get_connections():
		btn_close.pressed.disconnect(c.callable)

	btn_eat.pressed.connect(_on_eat_pressed)
	btn_leave.pressed.connect(_on_leave_pressed)
	btn_close.pressed.connect(_close_ui)

	btn_eat.disabled = false
	btn_leave.disabled = false

	mushroom_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_ui():
	ui_open = false
	mushroom_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_viewport().set_input_as_handled()

func _on_eat_pressed():
	if current_data.action == "EAT":
		result_label.text = "✓ CORRECT! " + current_data.name + "\n" + current_data.effect
		result_label.add_theme_color_override("font_color", Color.GREEN)
		
		# Call heal on the Explorer
		if current_player and current_player.has_method("heal"):
			current_player.heal(int(current_data.heal))
	else:
		result_label.text = "✗ WRONG! " + current_data.name + "\n" + current_data.effect
		result_label.add_theme_color_override("font_color", Color.RED)
		
		# Call damage on the Explorer
		if current_player and current_player.has_method("take_damage"):
			current_player.take_damage(int(current_data.damage))

	btn_eat.disabled = true
	btn_leave.disabled = true
	already_picked = true
	_close_ui()
	await get_tree().create_timer(2.0, true).timeout
	queue_free()

func _on_leave_pressed():
	if current_data.action == "LEAVE":
		result_label.text = "✓ CORRECT! Smart choice.\n" + current_data.name + " - " + current_data.effect
		result_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_label.text = "✗ WRONG! You should have eaten it.\n" + current_data.name + " - " + current_data.effect
		result_label.add_theme_color_override("font_color", Color.RED)
		
		# Call damage on the Explorer
		if current_player and current_player.has_method("take_damage"):
			current_player.take_damage(int(current_data.damage))

	btn_eat.disabled = true
	btn_leave.disabled = true
	already_picked = true
	_close_ui()
	await get_tree().create_timer(2.0, true).timeout
	queue_free()

func _on_body_entered(body: Node3D):
	# Using "explorer" since your explorer adds itself to this group in its _ready() function
	if body.is_in_group("explorer"):
		player_nearby = true
		current_player = body
		prompt_label.visible = not already_picked

func _on_body_exited(body: Node3D):
	if body == current_player:
		player_nearby = false
		current_player = null
		prompt_label.visible = false
		if ui_open:
			_close_ui()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open and not already_picked:
			_open_ui()
		elif ui_open:
			_close_ui()
