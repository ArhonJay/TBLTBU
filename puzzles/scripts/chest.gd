extends StaticBody3D

# ── Inspector exports ─────────────────────────────────────────────────────────
@export var picklock_ui: Node

# ── Constants ─────────────────────────────────────────────────────────────────
const OPEN_ANIM  := "Cylinder_001Action"
const WOOD_COLOR := Color(0.45, 0.28, 0.12)

# ── One-time manual flags (persist for the lifetime of the scene) ─────────────
static var _potion_manual_obtained  := false
static var _radio_manual_obtained   := false

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

	# ── Notify objective tracker ──────────────────────────────────────────────
	ObjectiveManager.register_chest_solved()

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

	# ── Build weighted loot pool ──────────────────────────────────────────────
	# Pool entries: [id, weight]
	# Manuals are only added if not yet obtained.
	var pool : Array = [
		["medkit",        3],
		["energy_drink",  3],
		["empty",         2],
	]
	if not _potion_manual_obtained:
		pool.append(["potion_manual", 1])
	if not _radio_manual_obtained:
		pool.append(["radio_manual",  1])

	var total_weight : int = 0
	for entry in pool:
		total_weight += entry[1]

	var roll : int = randi() % total_weight
	var chosen := "empty"
	var acc    := 0
	for entry in pool:
		acc += entry[1]
		if roll < acc:
			chosen = entry[0]
			break

	# ── Resolve chosen loot ───────────────────────────────────────────────────
	match chosen:
		"empty":
			print("Chest: No loot this time.")
			_show_obtained_popup(player, "The chest was empty...", null, false, 0.0)
			return

		"medkit":
			var item := {
				"id":          "medkit",
				"name":        "Medkit",
				"description": "Restores 50 HP when used.",
				"type":        "consumable",
				"heal_amount": 50,
				"count":       1,
				"icon":        _make_medkit_icon(),
			}
			_try_add_item(player, inventory, item)

		"energy_drink":
			var item := {
				"id":           "energy_drink",
				"name":         "Energy Drink",
				"description":  "Restores 50 stamina when used.",
				"type":         "consumable",
				"stamina_restore": 50.0,
				"count":        1,
				"icon":         _make_energy_drink_icon(),
			}
			_try_add_item(player, inventory, item)

		"potion_manual":
			_potion_manual_obtained = true
			var tex : Texture2D = _load_manual_texture("res://assets/manual/potion_manual.png")
			var item := {
				"id":          "potion_manual",
				"name":        "Potion Puzzle Manual",
				"description": "A manual for the potion puzzle.",
				"type":        "manual",
				"count":       1,
				"icon":        tex,
			}
			_try_add_manual(player, inventory, item, "Potion Puzzle Manual", tex)

		"radio_manual":
			_radio_manual_obtained = true
			var tex : Texture2D = _load_manual_texture("res://assets/manual/radio_manual.png")
			var item := {
				"id":          "radio_manual",
				"name":        "Radio Puzzle Manual",
				"description": "A manual for the radio puzzle.",
				"type":        "manual",
				"count":       1,
				"icon":        tex,
			}
			_try_add_manual(player, inventory, item, "Radio Puzzle Manual", tex)


# ── Add a regular consumable item ─────────────────────────────────────────────
func _try_add_item(player: Node, inventory: Node, item: Dictionary) -> void:
	var added : bool = inventory.add_item(item)
	if added:
		print("Chest: '%s' placed in player inventory." % item["name"])
		_show_obtained_popup(player, "You obtained a %s!" % item["name"], item["icon"], true, 0.0)
	else:
		push_warning("Chest: Inventory full — '%s' could not be added." % item["name"])
		_show_obtained_popup(player, "Inventory full! No room for %s." % item["name"], item["icon"], false, 0.0)


# ── Add a manual item with its special full-screen popup ──────────────────────
func _try_add_manual(player: Node, inventory: Node, item: Dictionary,
		display_name: String, tex: Texture2D) -> void:
	var added : bool = inventory.add_item(item)
	if added:
		print("Chest: '%s' added to inventory." % display_name)
		_show_manual_popup(player, display_name, tex)
	else:
		push_warning("Chest: Inventory full — '%s' could not be added." % display_name)
		_show_obtained_popup(player, "Inventory full! Can't store %s." % display_name, tex, false, 0.0)


# ── Load a PNG texture from res:// path safely ───────────────────────────────
func _load_manual_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Chest: Manual texture not found at '%s'." % path)
	return null


# ── Manual obtained — full-screen modal popup ─────────────────────────────────
func _show_manual_popup(player: Node, manual_name: String, tex: Texture2D) -> void:
	var popup_name := "_ManualPopup_" + manual_name.replace(" ", "_")
	var old := player.get_node_or_null(popup_name)
	if old:
		old.queue_free()

	var layer := CanvasLayer.new()
	layer.name  = popup_name
	layer.layer = 12
	player.add_child(layer)

	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	# Centred card
	var panel := PanelContainer.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color           = Color(0.08, 0.07, 0.05, 0.97)
	ps.set_corner_radius_all(14)
	ps.border_width_top    = 2; ps.border_width_bottom = 2
	ps.border_width_left   = 2; ps.border_width_right  = 2
	ps.border_color        = Color(0.85, 0.70, 0.20, 1.0)
	ps.content_margin_top    = 28.0; ps.content_margin_bottom = 28.0
	ps.content_margin_left   = 36.0; ps.content_margin_right  = 36.0
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -260.0
	panel.offset_right  =  260.0
	panel.offset_top    = -300.0
	panel.offset_bottom =  300.0
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Header label
	var header := Label.new()
	header.text = "MANUAL OBTAINED"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.85, 0.70, 0.20, 1.0))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Manual image preview
	if tex != null:
		var img_rect := TextureRect.new()
		img_rect.texture              = tex
		img_rect.custom_minimum_size  = Vector2(380, 280)
		img_rect.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_rect.expand_mode          = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		vbox.add_child(img_rect)
	else:
		var placeholder := Label.new()
		placeholder.text = "[image not found]"
		placeholder.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(placeholder)

	# Manual name
	var name_lbl := Label.new()
	name_lbl.text = manual_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Sub-label
	var sub_lbl := Label.new()
	sub_lbl.text = "Added to your inventory."
	sub_lbl.add_theme_font_size_override("font_size", 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.63, 0.58, 1.0))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	# Dismiss button
	var btn := Button.new()
	btn.text = "  OK  "
	btn.add_theme_font_size_override("font_size", 15)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.22, 0.18, 0.06, 1.0)
	btn_style.set_corner_radius_all(8)
	btn_style.border_width_top = 2; btn_style.border_width_bottom = 2
	btn_style.border_width_left = 2; btn_style.border_width_right = 2
	btn_style.border_color = Color(0.85, 0.70, 0.20, 0.9)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(func():
		layer.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)
	vbox.add_child(btn)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	panel.modulate.a = 0.0
	var tween := player.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)


# ── Item obtained popup ───────────────────────────────────────────────────────
func _show_obtained_popup(player: Node, message: String, icon,
		success: bool, delay: float = 0.0) -> void:

	var popup_name := "_ItemPopup_" + message.left(20).replace(" ", "_")
	var old := player.get_node_or_null(popup_name)
	if old:
		old.queue_free()

	var layer := CanvasLayer.new()
	layer.name  = popup_name
	layer.layer = 10
	player.add_child(layer)

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


func _make_energy_drink_icon() -> ImageTexture:
	var size := 64
	var img  := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var can_col    := Color(0.10, 0.10, 0.12, 1.0)
	var accent_col := Color(0.15, 0.90, 0.40, 1.0)  # bright green
	var rim_col    := Color(0.70, 0.70, 0.75, 1.0)
	var shine_col  := Color(0.85, 1.00, 0.88, 0.55)

	# Can body — rounded rectangle centred
	var cx1 := 18; var cx2 := 46
	var cy1 := 8;  var cy2 := 58
	var cr  := 6
	for y in range(cy1, cy2):
		for x in range(cx1, cx2):
			var in_corner := (
				(x < cx1+cr and y < cy1+cr and Vector2(x-cx1-cr, y-cy1-cr).length() > cr) or
				(x > cx2-cr-1 and y < cy1+cr and Vector2(x-(cx2-cr-1), y-cy1-cr).length() > cr) or
				(x < cx1+cr and y > cy2-cr-1 and Vector2(x-cx1-cr, y-(cy2-cr-1)).length() > cr) or
				(x > cx2-cr-1 and y > cy2-cr-1 and Vector2(x-(cx2-cr-1), y-(cy2-cr-1)).length() > cr)
			)
			if not in_corner:
				img.set_pixel(x, y, can_col)

	# Accent stripe (top third of can)
	for y in range(cy1 + 4, cy1 + 18):
		for x in range(cx1 + 2, cx2 - 2):
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, accent_col)

	# Rim lines top & bottom
	for x in range(cx1 + 2, cx2 - 2):
		img.set_pixel(x, cy1,     rim_col)
		img.set_pixel(x, cy1 + 1, rim_col)
		img.set_pixel(x, cy2 - 1, rim_col)
		img.set_pixel(x, cy2 - 2, rim_col)

	# Shine highlight
	for y in range(cy1 + 5, cy2 - 5):
		for x in range(cx1 + 3, cx1 + 8):
			if img.get_pixel(x, y).a > 0.0:
				img.set_pixel(x, y, shine_col)

	# Lightning bolt (stamina symbol) in white
	var bolt : Array = [
		[35, 18], [29, 33], [33, 33], [27, 48],
	]
	var bolt_col := Color(1.0, 1.0, 1.0, 1.0)
	for i in range(bolt.size() - 1):
		var p0 := Vector2(bolt[i][0],   bolt[i][1])
		var p1 := Vector2(bolt[i+1][0], bolt[i+1][1])
		var steps := int(p0.distance_to(p1)) * 2
		for s in range(steps + 1):
			var t := float(s) / float(steps)
			var px := int(lerp(p0.x, p1.x, t))
			var py := int(lerp(p0.y, p1.y, t))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var fx := px + dx; var fy := py + dy
					if fx >= 0 and fx < size and fy >= 0 and fy < size:
						if img.get_pixel(fx, fy).a > 0.0:
							img.set_pixel(fx, fy, bolt_col)

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
