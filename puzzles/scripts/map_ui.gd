extends CanvasLayer

const MAP_IMAGE_PATH = "res://puzzles/scenes/map.png"

var has_map := false
var _map_open := false

var _toast: PanelContainer = null
var _map_panel: Control = null


func _ready():
	layer = 5
	_build_toast()
	_build_map_viewer()


# ─── TOAST ────────────────────────────────────────────────────────────────────

func _build_toast():
	_toast = PanelContainer.new()

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.92)
	style.corner_radius_top_left    = 10
	style.corner_radius_top_right   = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_color = Color(0.75, 0.6, 0.2, 1.0)
	style.content_margin_left   = 20
	style.content_margin_right  = 20
	style.content_margin_top    = 12
	style.content_margin_bottom = 12
	_toast.add_theme_stylebox_override("panel", style)

	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.anchor_left   = 0.5
	_toast.anchor_right  = 0.5
	_toast.offset_left   = -260.0
	_toast.offset_right  = 260.0
	_toast.offset_top    = -100.0
	_toast.offset_bottom = -30.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	_toast.add_child(hbox)

	var icon_label = Label.new()
	icon_label.text = "🗺️"
	icon_label.add_theme_font_size_override("font_size", 28)
	hbox.add_child(icon_label)

	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)

	var title = Label.new()
	title.text = "Item Obtained!"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.75, 0.6, 0.2, 1.0))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "Obtained a map  —  press [M] to use"
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1.0))
	vbox.add_child(desc)

	_toast.visible = false
	add_child(_toast)


func _show_toast():
	_toast.visible = true
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(_toast):
		_toast.visible = false


# ─── MAP VIEWER ───────────────────────────────────────────────────────────────

func _build_map_viewer():
	_map_panel = Control.new()
	_map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_panel.add_child(dim)

	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.14, 0.09, 0.97)
	panel_style.corner_radius_top_left    = 12
	panel_style.corner_radius_top_right   = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.border_width_top    = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left   = 3
	panel_style.border_width_right  = 3
	panel_style.border_color = Color(0.65, 0.5, 0.2, 1.0)
	panel_style.content_margin_left   = 16
	panel_style.content_margin_right  = 16
	panel_style.content_margin_top    = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -560.0
	panel.offset_right  = 560.0
	panel.offset_top    = -380.0
	panel.offset_bottom = 380.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_map_panel.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "🗺️  Island Map"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.4, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✕  Close  [M]"
	close_btn.add_theme_font_size_override("font_size", 14)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.35, 0.22, 0.08, 1.0)
	close_style.corner_radius_top_left    = 6
	close_style.corner_radius_top_right   = 6
	close_style.corner_radius_bottom_left = 6
	close_style.corner_radius_bottom_right = 6
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(_close_map)
	header.add_child(close_btn)

	# Map image
	var texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.custom_minimum_size   = Vector2(0, 500)

	var tex = load(MAP_IMAGE_PATH)
	if tex:
		texture_rect.texture = tex
	else:
		var fallback = Label.new()
		fallback.text = "map.png not found at:\n" + MAP_IMAGE_PATH
		fallback.add_theme_color_override("font_color", Color.RED)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(fallback)

	vbox.add_child(texture_rect)

	_map_panel.visible = false
	add_child(_map_panel)


func _open_map():
	_map_open = true
	_map_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close_map():
	_map_open = false
	_map_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ─── INPUT ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent):
	if not has_map:
		return
	if event.is_action_pressed("open_map"):
		if _map_open:
			_close_map()
		else:
			_open_map()


# ─── PUBLIC — called by new_potion.gd signal ─────────────────────────────────

func give_map():
	has_map = true
	_show_toast()
