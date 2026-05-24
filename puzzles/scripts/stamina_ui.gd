extends CanvasLayer

@onready var stamina_bar: ProgressBar = $Control/StaminaPanel/VBox/StaminaBar
@onready var stamina_label: Label = $Control/StaminaPanel/VBox/StaminaLabel

func _ready():
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	_refresh_bar_color(100.0, 100.0)

func update_stamina(current: float, maximum: float):
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "STA: " + str(int(current))
	_refresh_bar_color(current, maximum)

func _refresh_bar_color(current: float, maximum: float):
	var fill = StyleBoxFlat.new()
	fill.corner_radius_top_left = 6
	fill.corner_radius_top_right = 6
	fill.corner_radius_bottom_left = 6
	fill.corner_radius_bottom_right = 6

	if current <= 0.0:
		# Depleted — dark burnt orange
		fill.bg_color = Color(0.5, 0.15, 0.02, 1.0)
	else:
		# Full = bright yellow, low = deep orange
		var t = current / maximum
		fill.bg_color = Color(0.95, 0.45 + 0.35 * t, 0.05 + 0.05 * t, 1.0)

	stamina_bar.add_theme_stylebox_override("fill", fill)
