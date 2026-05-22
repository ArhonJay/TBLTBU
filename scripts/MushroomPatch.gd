# MushroomPatch.gd
# Attach to a Node3D (StaticBody3D recommended) in your scene.
# This represents one physical mushroom patch the player walks up to.
extends StaticBody3D

## Set this in the Inspector to one of: "glowing_blue", "red_spotted", "pale_fleshy"
@export var mushroom_id: String = "glowing_blue"

## How close the player must be to trigger the [E] prompt (meters)
@export var interaction_radius: float = 2.5

## Reference to your MycologyUI node (assign in Inspector or via path)
@export var ui_node_path: NodePath = ""

@onready var interaction_label: Label3D = $InteractionLabel  # [E] Interact label above patch
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _ui: Node = null
var _player_nearby: bool = false
var _player: Node3D = null

func _ready() -> void:
	# Hide the [E] prompt initially
	if interaction_label:
		interaction_label.visible = false

	# Resolve UI reference
	if ui_node_path != "":
		_ui = get_node(ui_node_path)
	else:
		# Fallback: search in the scene root for a node named MycologyUI
		_ui = get_tree().get_first_node_in_group("mycology_ui")

	if _ui == null:
		push_warning("MushroomPatch: No MycologyUI found. Set ui_node_path in Inspector.")

func _process(_delta: float) -> void:
	if _player == null:
		return

	var dist: float = global_position.distance_to(_player.global_position)
	var in_range: bool = dist <= interaction_radius

	if in_range != _player_nearby:
		_player_nearby = in_range
		if interaction_label:
			interaction_label.visible = _player_nearby

	# Check for E key press
	if _player_nearby and Input.is_action_just_pressed("interact"):
		_open_puzzle()

## Call this from your Area3D body_entered signal, OR use the _process distance check above.
## If you use Area3D, connect body_entered → _on_body_entered and body_exited → _on_body_exited
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body
		_player_nearby = true
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = null
		_player_nearby = false
		if interaction_label:
			interaction_label.visible = false

func _open_puzzle() -> void:
	if _ui == null:
		push_error("MushroomPatch: Cannot open puzzle — MycologyUI not found.")
		return
	var data: Dictionary = MycologyData.get_mushroom(mushroom_id)
	if data.is_empty():
		push_error("MushroomPatch: Unknown mushroom_id '%s'" % mushroom_id)
		return
	_ui.open_puzzle(data)
