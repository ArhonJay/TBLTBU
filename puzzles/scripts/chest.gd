extends StaticBody3D

# ── Inspector exports ─────────────────────────────────────────────────────────
@export var picklock_ui: Node

# ── Constants ─────────────────────────────────────────────────────────────────
const OPEN_ANIM  := "Cylinder_001Action"
const WOOD_COLOR := Color(0.45, 0.28, 0.12)

# ── State ─────────────────────────────────────────────────────────────────────
var player_nearby := false
var ui_open       := false
var is_solved     := false
var prompt_label  : Label3D
var anim_player   : AnimationPlayer


func _ready() -> void:
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)

	prompt_label              = Label3D.new()
	prompt_label.text         = "Press E to interact"
	prompt_label.position     = Vector3(0, 1.5, 0.1)
	prompt_label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size    = 48
	prompt_label.outline_size = 8
	prompt_label.visible      = false
	add_child(prompt_label)

	var chest_model := find_child("ChestModel", true, false)
	if chest_model == null:
		push_error("Chest: 'ChestModel' node not found.")
	else:
		anim_player = _find_animation_player(chest_model)
		if anim_player:
			anim_player.stop()
		else:
			push_warning("Chest: AnimationPlayer not found inside ChestModel.")

	_apply_wood_color()

	if picklock_ui == null:
		push_error("Chest: 'picklock_ui' export is not set in the Inspector!")
		return

	picklock_ui.connect("lock_success", _on_lock_success)
	picklock_ui.connect("lock_failed",  _on_lock_failed)
	picklock_ui.visible = false


# ── Helpers ───────────────────────────────────────────────────────────────────
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _apply_wood_color() -> void:
	var chest_model := find_child("ChestModel", true, false)
	if chest_model == null:
		return
	var meshes : Array = []
	_collect_meshes(chest_model, meshes)
	for mesh_instance in meshes:
		var surface_count : int = mesh_instance.get_surface_override_material_count()
		for i in range(surface_count):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = WOOD_COLOR
			mat.roughness    = 0.85
			mat.metallic     = 0.0
			mesh_instance.set_surface_override_material(i, mat)


# ── Picklock modal ────────────────────────────────────────────────────────────
func _open_picklock() -> void:
	ui_open              = true
	prompt_label.visible = false
	picklock_ui.open()


func _close_picklock() -> void:
	ui_open = false
	if picklock_ui:
		picklock_ui.close()


func _on_lock_success() -> void:
	ui_open   = false
	is_solved = true
	set_process_unhandled_input(false)
	$InteractionZone.monitoring = false
	_on_chest_unlocked()


func _on_lock_failed() -> void:
	ui_open              = false
	prompt_label.text    = "Press E to interact"
	prompt_label.visible = player_nearby and not is_solved


# ── Chest unlocked ────────────────────────────────────────────────────────────
func _on_chest_unlocked() -> void:
	prompt_label.visible = false
	if anim_player and anim_player.has_animation(OPEN_ANIM):
		anim_player.play(OPEN_ANIM)
	else:
		push_warning("Chest: animation '%s' not found. Available: %s" % [
			OPEN_ANIM,
			str(anim_player.get_animation_list()) if anim_player else "no AnimationPlayer"
		])
	_give_items_to_player()


# ── Give items to player ──────────────────────────────────────────────────────
func _give_items_to_player() -> void:
	var players := get_tree().get_nodes_in_group("explorer")
	if players.is_empty():
		push_warning("Chest: No node in group 'explorer' found.")
		return

	# Pick the closest explorer (safe for multiplayer)
	var player : Node = players[0]
	if players.size() > 1:
		var min_dist := INF
		for p in players:
			var d := global_position.distance_to((p as Node3D).global_position)
			if d < min_dist:
				min_dist = d
				player   = p

	var inventory := player.get_node_or_null("InventoryUI")
	if inventory == null:
		push_warning("Chest: Player has no 'InventoryUI' child.")
		return

	# ── Randomise loot: 1/3 medkit, 1/3 battery, 1/3 nothing ────────────────
	var roll : int = randi() % 3   # 0 = medkit, 1 = battery, 2 = nothing

	if roll == 2:
		# Empty chest
		print("Chest: No loot this time.")
		_show_obtained_popup(player, "The chest was empty...", null, false, 0.0)
		return

	var item : Dictionary
	if roll == 0:
		item = {
			"id":          "medkit",
			"name":        "Medkit",
			"description": "Restores 50 HP when used.",
			"type":        "consumable",
			"heal_amount": 50,
			"count":       1,
			"icon":        _make_medkit_icon(),
		}
	else:
		item = {
			"id":           "battery",
			"name":         "Drone Battery",
			"description":  "+5s drone flight time.",
			"type":         "consumable",
			"flight_bonus": 5,
			"count":        1,
			"icon":         _make_battery_icon(),
		}

	var added : bool = inventory.add_item(item)
	if added:
		print("Chest: '%s' placed in player inventory." % item["name"])
		_show_obtained_popup(player, "You obtained a %s!" % item["name"], item["icon"], true, 0.0)
	else:
		push_warning("Chest: Inventory full — '%s' could not be added." % item["name"])
		_show_obtained_popup(player, "Inventory full! No room for %s." % item["name"], item["icon"], false, 0.0)


# ── Item obtained popup ───────────────────────────────────────────────────────
func _show_obtained_popup(player: Node, message: String, icon,
		success: bool, delay: float = 0.0) -> void:

	# Unique name per message so multiple popups can stack
	var popup_name := "_ItemPopup_" + message.left(20).replace(" ", "_")
	var old := player.get_node_or_null(popup_name)
	if old:
		old.queue_free()

	var layer := CanvasLayer.new()
	layer.name  = popup_name
	layer.layer = 10
	player.add_child(layer)

	# Panel
	var panel := PanelContainer.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color           = Color(0.06, 0.06, 0.08, 0.88)
	ps.set_corner_radius_all(10)
	ps.border_width_top    = 2; ps.border_width_bottom = 2
	ps.border_width_left   = 2; ps.border_width_right  = 2
	ps.border_color        = Color(0.85, 0.70, 0.20, 0.9) if success else Color(0.45, 0.43, 0.40, 0.7)
	ps.content_margin_top    = 14.0; ps.content_margin_bottom = 14.0
	ps.content_margin_left   = 22.0; ps.content_margin_right  = 22.0
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.anchor_top    = 0.12
	panel.anchor_bottom = 0.12
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_END
	layer.add_child(panel)

	# HBox: icon + text
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	var icon_rect := TextureRect.new()
	icon_rect.texture             = icon
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.visible             = icon != null
	hbox.add_child(icon_rect)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var title_lbl := Label.new()
	if success:
		title_lbl.text = "ITEM OBTAINED"
		title_lbl.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20, 1.0))
	elif icon == null:
		title_lbl.text = "CHEST EMPTY"
		title_lbl.add_theme_color_override("font_color", Color(0.55, 0.53, 0.50, 1.0))
	else:
		title_lbl.text = "CHEST"
		title_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = message
	msg_lbl.add_theme_font_size_override("font_size", 17)
	msg_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
	vbox.add_child(msg_lbl)

	# Fade in → hold → fade out — with optional delay for staggering
	panel.modulate.a = 0.0
	var tween := player.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.4)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)


# ── Icons ─────────────────────────────────────────────────────────────────────
func _make_medkit_icon() -> ImageTexture:
	var size := 64
	var img  := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white := Color(0.95, 0.95, 0.95, 1.0)
	var red   := Color(0.85, 0.10, 0.10, 1.0)
	var pad := 4; var r := 8
	for y in range(pad, size - pad):
		for x in range(pad, size - pad):
			var ic := (
				(x < pad+r and y < pad+r and Vector2(x-pad-r, y-pad-r).length() > r) or
				(x > size-pad-r-1 and y < pad+r and Vector2(x-(size-pad-r-1), y-pad-r).length() > r) or
				(x < pad+r and y > size-pad-r-1 and Vector2(x-pad-r, y-(size-pad-r-1)).length() > r) or
				(x > size-pad-r-1 and y > size-pad-r-1 and Vector2(x-(size-pad-r-1), y-(size-pad-r-1)).length() > r)
			)
			if not ic:
				img.set_pixel(x, y, white)
	var aw := 10; var ao := 14; var cx := size/2; var cy := size/2
	for y in range(cy - aw/2, cy + aw/2):
		for x in range(ao, size - ao):
			img.set_pixel(x, y, red)
	for x in range(cx - aw/2, cx + aw/2):
		for y in range(ao, size - ao):
			img.set_pixel(x, y, red)
	return ImageTexture.create_from_image(img)


func _make_battery_icon() -> ImageTexture:
	var size := 64
	var img  := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var body_col := Color(0.20, 0.20, 0.22, 1.0)   # dark grey casing
	var fill_col := Color(0.25, 0.85, 0.35, 1.0)   # green charge fill
	var rim_col  := Color(0.65, 0.65, 0.70, 1.0)   # light grey rim
	var nub_col  := Color(0.60, 0.60, 0.65, 1.0)   # positive terminal nub

	# Battery body rect
	var bx1 := 8; var bx2 := 52
	var by1 := 16; var by2 := 48
	for y in range(by1, by2):
		for x in range(bx1, bx2):
			img.set_pixel(x, y, body_col)

	# Green fill (left ~70% of interior)
	var fill_x2 := bx1 + int((bx2 - bx1) * 0.68)
	for y in range(by1 + 4, by2 - 4):
		for x in range(bx1 + 4, fill_x2):
			img.set_pixel(x, y, fill_col)

	# Rim (border around body)
	for x in range(bx1, bx2):
		img.set_pixel(x, by1, rim_col)
		img.set_pixel(x, by2 - 1, rim_col)
	for y in range(by1, by2):
		img.set_pixel(bx1, y, rim_col)
		img.set_pixel(bx2 - 1, y, rim_col)

	# Positive terminal nub (right side)
	var nx1 := bx2; var nx2 := bx2 + 6
	var ny1 := (by1 + by2) / 2 - 5
	var ny2 := (by1 + by2) / 2 + 5
	for y in range(ny1, ny2):
		for x in range(nx1, nx2):
			img.set_pixel(x, y, nub_col)

	# Lightning bolt (white, centred)
	# Draw a simple zigzag: top-right → mid-left → bottom-right
	var bolt_pts : Array = [
		[36, 20], [30, 32], [34, 32], [28, 44],
	]
	for i in range(bolt_pts.size() - 1):
		var p0 := Vector2(bolt_pts[i][0], bolt_pts[i][1])
		var p1 := Vector2(bolt_pts[i+1][0], bolt_pts[i+1][1])
		var steps := int(p0.distance_to(p1)) * 2
		for s in range(steps + 1):
			var t := float(s) / float(steps)
			var px := int(lerp(p0.x, p1.x, t))
			var py := int(lerp(p0.y, p1.y, t))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var fx := px + dx; var fy := py + dy
					if fx >= 0 and fx < size and fy >= 0 and fy < size:
						img.set_pixel(fx, fy, Color(1, 1, 1, 1))

	return ImageTexture.create_from_image(img)


# ── Proximity ─────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		if not is_solved:
			prompt_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_nearby        = false
		prompt_label.visible = false
		if ui_open:
			_close_picklock()


# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open and not is_solved:
			_open_picklock()
		elif ui_open:
			_close_picklock()
