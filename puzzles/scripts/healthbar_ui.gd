extends CanvasLayer

@export var max_health: float = 100.0
var current_health: float = 100.0

@onready var health_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $Control/PanelContainer/VBoxContainer/HealthLabel
@onready var status_popup: Label = $Control/StatusPopup
@onready var game_over_modal = $Control/GameOverModal

func _ready():
	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	health_bar.value = current_health
	game_over_modal.visible = false
	_update_ui()

func _update_ui():
	health_bar.value = current_health
	health_label.text = "HP: " + str(int(current_health))

	var fill_style = StyleBoxFlat.new()
	if current_health > 60:
		fill_style.bg_color = Color(0.1, 0.8, 0.1)
	elif current_health > 30:
		fill_style.bg_color = Color(0.9, 0.7, 0.1)
	else:
		fill_style.bg_color = Color(0.9, 0.1, 0.1)
	health_bar.add_theme_stylebox_override("fill", fill_style)

func update_health(current: int, maximum: int):
	max_health = float(maximum)
	current_health = float(current)
	health_bar.max_value = max_health
	_update_ui()

func show_game_over():
	game_over_modal.visible = true

func heal(amount: float):
	current_health = min(current_health + amount, max_health)
	_update_ui()
	_show_popup("✓ +" + str(int(amount)) + " HP!", Color.GREEN)

func damage(amount: float):
	current_health = max(current_health - amount, 0.0)
	_update_ui()
	_show_popup("✗ -" + str(int(amount)) + " HP!", Color.RED)
	if current_health <= 0:
		_on_dead()

var _popup_timer: SceneTreeTimer = null

func _show_popup(text: String, color: Color):
	if _popup_timer != null:
		_popup_timer.timeout.disconnect(_hide_popup)
		_popup_timer = null
	status_popup.text = text
	status_popup.add_theme_color_override("font_color", color)
	status_popup.visible = true
	_popup_timer = get_tree().create_timer(2.0)
	_popup_timer.timeout.connect(_hide_popup)
	await _popup_timer.timeout

func _hide_popup():
	status_popup.visible = false
	_popup_timer = null

func _on_dead():
	_show_popup("YOU DIED", Color.RED)

func _on_back_to_menu_pressed():
	# Ask the explorer (our parent) to RPC the scene change to all peers.
	# Because _go_to_main_menu_from_explorer is "any_peer", any player can call it.
	var explorer = get_parent()
	if explorer and explorer.has_method("_go_to_main_menu_from_explorer"):
		explorer._go_to_main_menu_from_explorer.rpc()
	else:
		# Fallback: reset network and change scene locally
		var nm = get_node_or_null("/root/NetworkManager")
		if nm:
			nm.reset()
		get_tree().change_scene_to_file("res://menu/MainMenu.tscn")
