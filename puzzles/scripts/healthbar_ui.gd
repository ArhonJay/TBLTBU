extends CanvasLayer

@export var max_health: float = 100.0

var current_health: float = 100.0  # Start at 50%

@onready var health_bar: ProgressBar = $Control/PanelContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $Control/PanelContainer/VBoxContainer/HealthLabel
@onready var status_popup: Label = $Control/StatusPopup

func _ready():
	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	health_bar.value = current_health
	_update_ui()

func _update_ui():
	health_bar.value = current_health
	health_label.text = "HP: " + str(int(current_health))
	
	# change color based on health
	var fill_style = StyleBoxFlat.new()
	if current_health > 60:
		fill_style.bg_color = Color(0.1, 0.8, 0.1)
	elif current_health > 30:
		fill_style.bg_color = Color(0.9, 0.7, 0.1)
	else:
		fill_style.bg_color = Color(0.9, 0.1, 0.1)
	health_bar.add_theme_stylebox_override("fill", fill_style)

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
	# Cancel any existing popup timer so they don't overlap
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
