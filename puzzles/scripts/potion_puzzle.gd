extends Node3D

@export var potion_ui: CanvasLayer

var buckets = []

const COLORS = ["Red", "Yellow", "Green", "Clear"]

var player_nearby := false
var ui_open := false
var puzzle_solved := false


var step := 1
var base_compound_amount := ""
var base_compound_bucket_index := -1

var instruction_label: Label
var result_label: Label
var pour_buttons_row: HBoxContainer
var bucket_panels: Array = []

var _correct_base_amount := ""
var _correct_base_color := ""
var _correct_catalyst_amount := ""
var _correct_catalyst_color := ""

var prompt_label: Label3D


func _ready():
	# temporary debug — find surface count
	
	prompt_label = Label3D.new()
	prompt_label.text = "Press E to interact"
	prompt_label.position = Vector3(0, 1.5, 0.1)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 48
	prompt_label.outline_size = 8
	prompt_label.visible = false
	add_child(prompt_label)
	
	await get_tree().process_frame
	for i in range(get_child_count()):
		var child = get_child(i)
		var mesh = _find_mesh_instance(child)
		if mesh:
			print("Child ", i, " name: ", child.name, " surface count: ", mesh.get_surface_override_material_count())
	
	# get UI refs
	instruction_label = potion_ui.get_node("Control/PanelContainer/VBoxContainer/InstructionLabel")
	result_label = potion_ui.get_node("Control/PanelContainer/VBoxContainer/ResultLabel")
	pour_buttons_row = potion_ui.get_node("Control/PanelContainer/VBoxContainer/PourButtonsRow")
	
	bucket_panels = [
		potion_ui.get_node("Control/PanelContainer/VBoxContainer/BucketRow/BucketPanel1/VBoxContainer"),
		potion_ui.get_node("Control/PanelContainer/VBoxContainer/BucketRow/BucketPanel2/VBoxContainer"),
		potion_ui.get_node("Control/PanelContainer/VBoxContainer/BucketRow/BucketPanel3/VBoxContainer"),
		potion_ui.get_node("Control/PanelContainer/VBoxContainer/BucketRow/BucketPanel4/VBoxContainer"),
	]
	
	# connect pour buttons
	potion_ui.get_node("Control/PanelContainer/VBoxContainer/PourButtonsRow/BtnHalfGreen").pressed.connect(func(): _on_pour_pressed("half", "Green"))
	potion_ui.get_node("Control/PanelContainer/VBoxContainer/PourButtonsRow/BtnAllRed").pressed.connect(func(): _on_pour_pressed("all", "Red"))
	potion_ui.get_node("Control/PanelContainer/VBoxContainer/PourButtonsRow/BtnQuarterClear").pressed.connect(func(): _on_pour_pressed("quarter", "Clear"))
	potion_ui.get_node("Control/PanelContainer/VBoxContainer/PourButtonsRow/BtnHalfYellow").pressed.connect(func(): _on_pour_pressed("half", "Yellow"))
	potion_ui.get_node("Control/CloseButton").pressed.connect(_close_ui)
	
	# connect interaction zones on all Bucket children
	for child in get_children():
		if child.has_node("InteractionZone"):
			child.get_node("InteractionZone").body_entered.connect(_on_body_entered)
			child.get_node("InteractionZone").body_exited.connect(_on_body_exited)
	
	potion_ui.visible = false
	_randomize_buckets()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func _apply_color_to_bucket(bucket_node: Node, color: String):
	var mesh = _find_mesh_instance(bucket_node)
	if not mesh:
		print("No mesh found on bucket: ", bucket_node.name)
		return
	
	var tint: Color
	match color:
		"Red":    tint = Color(1.0, 0.2, 0.2, 0.8)
		"Yellow": tint = Color(1.0, 1.0, 0.2, 0.8)
		"Green":  tint = Color(0.2, 1.0, 0.2, 0.8)
		"Clear":  tint = Color(0.9, 0.9, 1.0, 0.4)
	
	var surface_count = mesh.get_surface_override_material_count()
	for i in range(surface_count):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tint
		if color == "Clear":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.set_surface_override_material(i, mat)

func _randomize_buckets():
	buckets.clear()
	
	var colors_shuffled = COLORS.duplicate()
	colors_shuffled.shuffle()
	
	# get the actual bucket child nodes
	var bucket_nodes = []
	for child in get_children():
		if child is StaticBody3D:
			bucket_nodes.append(child)
	
	for i in range(4):
		buckets.append({
			"color": colors_shuffled[i],
			"bubbling": bool(randi() % 2),
			"cracked": bool(randi() % 2),
			"position": i + 1,
			"node": bucket_nodes[i] if i < bucket_nodes.size() else null
		})
		
		# apply color to the actual 3D mesh
		if bucket_nodes.size() > i:
			_apply_color_to_bucket(bucket_nodes[i], colors_shuffled[i])
	
	print("=== BUCKET STATES ===")
	for b in buckets:
		print("Pos ", b.position, ": ", b.color, " | Bubbling: ", b.bubbling, " | Cracked: ", b.cracked)
	
	_determine_correct_pours()

func _determine_correct_pours():
	var green_bucket = _get_bucket_by_color("Green")
	var red_bucket = _get_bucket_by_color("Red")
	var clear_bucket = _get_bucket_by_color("Clear")
	var yellow_bucket = _get_bucket_by_color("Yellow")
	var any_bubbling = buckets.any(func(b): return b.bubbling)
	
	# STEP 1: BASE COMPOUND
	var base_color := ""
	var base_amount := ""
	var base_index := -1
	
	if green_bucket.get("cracked", false):
		base_color = "Green"
		base_amount = "half"
		base_index = buckets.find(green_bucket)
	elif any_bubbling:
		base_color = "Red"
		base_amount = "all"
		base_index = buckets.find(red_bucket)
	elif clear_bucket.get("position", 0) == 1 or clear_bucket.get("position", 0) == 2:
		base_color = "Clear"
		base_amount = "quarter"
		base_index = buckets.find(clear_bucket)
	else:
		base_color = "Yellow"
		base_amount = "half"
		base_index = buckets.find(yellow_bucket)
	
	# STEP 2: CATALYST
	var catalyst_color := ""
	var catalyst_amount := ""
	
	if base_amount == "half":
		var bubbling_bucket = null
		for b in buckets:
			if b.bubbling:
				bubbling_bucket = b
				break
		if bubbling_bucket:
			catalyst_color = bubbling_bucket.color
		else:
			catalyst_color = buckets[3].color
		catalyst_amount = "quarter"
	else:
		var next_index = (base_index + 1) % 4
		catalyst_color = buckets[next_index].color
		catalyst_amount = "half"
	
	_correct_base_amount = base_amount
	_correct_base_color = base_color
	_correct_catalyst_amount = catalyst_amount
	_correct_catalyst_color = catalyst_color
	
	print("=== CORRECT POURS ===")
	print("Step 1 (Base): ", base_amount.to_upper(), " of ", base_color)
	print("Step 2 (Catalyst): ", catalyst_amount.to_upper(), " of ", catalyst_color)

func _get_bucket_by_color(color: String) -> Dictionary:
	for b in buckets:
		if b.color == color:
			return b
	return {}

func _on_pour_pressed(amount: String, color: String):
	if step == 1:
		if amount == _correct_base_amount and color == _correct_base_color:
			result_label.text = "✓ Good! Now select the CATALYST:"
			result_label.add_theme_color_override("font_color", Color.GREEN)
			instruction_label.text = "Select the CATALYST pour:"
			step = 2
			_update_pour_buttons_for_step2()
		else:
			result_label.text = "✗ Wrong pour! Try again."
			result_label.add_theme_color_override("font_color", Color.RED)
	elif step == 2:
		if amount == _correct_catalyst_amount and color == _correct_catalyst_color:
			result_label.text = "✓ PUZZLE COMPLETE! Fuel Stabilized!"
			result_label.add_theme_color_override("font_color", Color.GREEN)
			puzzle_solved = true
			_disable_pour_buttons()
		else:
			result_label.text = "✗ Wrong catalyst! Try again."
			result_label.add_theme_color_override("font_color", Color.RED)

func _update_pour_buttons_for_step2():
	for child in pour_buttons_row.get_children():
		pour_buttons_row.remove_child(child)
		child.queue_free()
	
	var options = [
		["quarter", "Red", "1/4 RED"],
		["quarter", "Yellow", "1/4 YELLOW"],
		["quarter", "Green", "1/4 GREEN"],
		["quarter", "Clear", "1/4 CLEAR"],
		["half", "Red", "1/2 RED"],
		["half", "Yellow", "1/2 YELLOW"],
		["half", "Green", "1/2 GREEN"],
		["half", "Clear", "1/2 CLEAR"],
		["all", "Clear", "ALL CLEAR"],
	]
	
	for opt in options:
		var btn = Button.new()
		btn.text = opt[2]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_pour_pressed(opt[0], opt[1]))
		pour_buttons_row.add_child(btn)

func _disable_pour_buttons():
	for child in pour_buttons_row.get_children():
		if child is Button:
			child.disabled = true

func _update_bucket_ui():
	for i in range(4):
		var panel = bucket_panels[i]
		var b = buckets[i]
		panel.get_node("PosLabel").text = "Position " + str(b.position)
		
		var color_label = panel.get_node("ColorLabel")
		color_label.text = b.color
		match b.color:
			"Red":    color_label.add_theme_color_override("font_color", Color.RED)
			"Yellow": color_label.add_theme_color_override("font_color", Color.YELLOW)
			"Green":  color_label.add_theme_color_override("font_color", Color.GREEN)
			"Clear":  color_label.add_theme_color_override("font_color", Color.WHITE)
		
		var state_label = panel.get_node("StateLabel")
		state_label.text = "Bubbling" if b.bubbling else "Calm"
		state_label.add_theme_color_override("font_color", Color.ORANGE if b.bubbling else Color.WHITE)
		
		var crack_label = panel.get_node("CrackLabel")
		crack_label.text = "CRACKED" if b.cracked else "Intact"
		crack_label.add_theme_color_override("font_color", Color.RED if b.cracked else Color.WHITE)

func _open_ui():
	ui_open = true
	step = 1
	instruction_label.text = "Select the BASE COMPOUND pour:"
	result_label.text = ""
	_update_bucket_ui()
	
	for child in pour_buttons_row.get_children():
		pour_buttons_row.remove_child(child)
		child.queue_free()
	
	var step1_options = [
		["half", "Green", "1/2 GREEN"],
		["all", "Red", "ALL RED"],
		["quarter", "Clear", "1/4 CLEAR"],
		["half", "Yellow", "1/2 YELLOW"],
	]
	for opt in step1_options:
		var btn = Button.new()
		btn.text = opt[2]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_pour_pressed(opt[0], opt[1]))
		pour_buttons_row.add_child(btn)
	
	potion_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_ui():
	ui_open = false
	potion_ui.visible = false
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
			_close_ui()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open and not puzzle_solved:
			_open_ui()
		elif ui_open:
			_close_ui()
