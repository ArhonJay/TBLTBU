extends Node3D

## Tornado waypoint movement script
## Attach this to the "Tornado" Node3D in main_scene.tscn

@export var move_speed: float = 10.0        # Units per second
@export var rotation_speed: float = 2.0     # How fast tornado spins (radians/sec)
@export var arrival_threshold: float = 1.0  # Distance to consider waypoint reached
@export var loop_waypoints: bool = true     # Loop back to waypoint 1 after last

var waypoints: Array[Marker3D] = []
var current_waypoint_index: int = 0
var is_moving: bool = true

# Cache the tornado's Y so it never drifts/disappears
var _locked_y: float = 0.0


func _ready() -> void:
	_collect_waypoints()
	if waypoints.is_empty():
		push_warning("Tornado: No Marker3D waypoints found as children!")
		is_moving = false
	else:
		# Lock Y to starting position so tornado never floats or falls
		_locked_y = global_position.y
		
	# --- NEW: Connect the KillZone signal ---
	var kill_zone = get_node_or_null("KillZone")
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	else:
		push_warning("Tornado: No 'KillZone' Area3D found! Tornado cannot kill.")

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("explorer") or body.is_in_group("scientist"):
		if body.has_method("catch_in_tornado"):
			body.catch_in_tornado(self)


func _process(delta: float) -> void:
	# Spin using only Y-axis rotation — avoids transform drift
	global_rotation.y += rotation_speed * delta

	if not is_moving or waypoints.is_empty():
		return

	_move_to_current_waypoint(delta)

	# Always restore Y so tornado never disappears off-axis
	global_position.y = _locked_y


func _move_to_current_waypoint(delta: float) -> void:
	var target: Marker3D = waypoints[current_waypoint_index]

	# Only compare X/Z distance — ignore Y so height lock isn't fought
	var target_xz := Vector2(target.global_position.x, target.global_position.z)
	var self_xz   := Vector2(global_position.x, global_position.z)
	var distance   := target_xz.distance_to(self_xz)

	if distance <= arrival_threshold:
		_advance_waypoint()
		return

	var dir_xz := (target_xz - self_xz).normalized()
	var step: float = min(move_speed * delta, distance)

	global_position.x += dir_xz.x * step
	global_position.z += dir_xz.y * step


func _advance_waypoint() -> void:
	current_waypoint_index += 1
	if current_waypoint_index >= waypoints.size():
		if loop_waypoints:
			current_waypoint_index = 0  # Loop back to waypoint 1
			print("Tornado: Looping back to waypoint 1.")
		else:
			current_waypoint_index = waypoints.size() - 1
			is_moving = false
			print("Tornado: Reached final waypoint, stopping.")


func _collect_waypoints() -> void:
	waypoints.clear()
	for child in get_children():
		if child is Marker3D:
			waypoints.append(child)

	# Sort numerically by the trailing number in the node name
	# e.g. "waypoint 1", "waypoint 9" — avoids alphabetical bug where "9" < "2"
	waypoints.sort_custom(func(a, b):
		var num_a := _extract_trailing_number(a.name)
		var num_b := _extract_trailing_number(b.name)
		return num_a < num_b
	)

	print("Tornado: Found %d waypoints in order:" % waypoints.size())
	for wp in waypoints:
		print("  - ", wp.name)


func _extract_trailing_number(node_name: String) -> int:
	# Grab the last space-separated token and convert to int
	var parts := node_name.split(" ")
	var last   := parts[parts.size() - 1]
	if last.is_valid_int():
		return last.to_int()
	return 0


## Call this from outside to pause/resume tornado movement
func set_moving(enabled: bool) -> void:
	is_moving = enabled


## Jump to a specific waypoint index immediately
func teleport_to_waypoint(index: int) -> void:
	if index < 0 or index >= waypoints.size():
		push_warning("Tornado: Waypoint index %d out of range." % index)
		return
	current_waypoint_index = index
	global_position.x = waypoints[index].global_position.x
	global_position.z = waypoints[index].global_position.z
