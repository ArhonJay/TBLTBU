extends StaticBody3D

# ── Inspector export ──────────────────────────────────────────────────────────
## Drag the PicklockUI node (NOT the CanvasLayer — the Node2D root of the scene)
## into this slot in the Inspector.
@export var picklock_ui: Node

# ── Constants ─────────────────────────────────────────────────────────────────
const OPEN_ANIM  := "Cylinder_001Action"
const WOOD_COLOR := Color(0.45, 0.28, 0.12)   # warm medium wood brown

# ── State ─────────────────────────────────────────────────────────────────────
var player_nearby := false
var ui_open       := false
var is_solved     := false
var prompt_label  : Label3D
var anim_player   : AnimationPlayer


func _ready() -> void:
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)

	# ── Floating prompt ──────────────────────────────────────────────────────
	prompt_label              = Label3D.new()
	prompt_label.text         = "Press E to interact"
	prompt_label.position     = Vector3(0, 1.5, 0.1)
	prompt_label.billboard    = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size    = 48
	prompt_label.outline_size = 8
	prompt_label.visible      = false
	add_child(prompt_label)

	# ── AnimationPlayer ──────────────────────────────────────────────────────
	var chest_model := find_child("ChestModel", true, false)
	if chest_model == null:
		push_error("Chest: 'ChestModel' node not found.")
	else:
		anim_player = _find_animation_player(chest_model)
		if anim_player:
			anim_player.stop()
		else:
			push_warning("Chest: AnimationPlayer not found inside ChestModel.")

	# ── Apply wood tint ──────────────────────────────────────────────────────
	_apply_wood_color()

	# ── Connect picklock signals ─────────────────────────────────────────────
	if picklock_ui == null:
		push_error("Chest: 'picklock_ui' export is not set in the Inspector!")
		return

	# The signals live on the script attached to the PicklockUI root node.
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
	prompt_label.text = "Unlocked"
	if anim_player and anim_player.has_animation(OPEN_ANIM):
		anim_player.play(OPEN_ANIM)
	else:
		push_warning("Chest: animation '%s' not found. Available: %s" % [
			OPEN_ANIM,
			str(anim_player.get_animation_list()) if anim_player else "no AnimationPlayer"
		])


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
