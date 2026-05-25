extends CanvasLayer
# game_manual_ui.gd
# All 9 pages stacked vertically in one ScrollContainer.
# Shown/hidden by game_manual.gd — no external scene needed.

signal manual_closed

# ── Page asset paths ─────────────────────────────────────────────────────────
const PAGES: Array[String] = [
	"res://assets/manual/1.png",
	"res://assets/manual/2.png",
	"res://assets/manual/3.png",
	"res://assets/manual/4.png",
	"res://assets/manual/6.png",
	"res://assets/manual/8.png",
	"res://assets/manual/9.png",
]

const PANEL_W: int = 860
const PANEL_H: int = 660

var _textures: Array[Texture2D] = []
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 10
	_load_textures()
	_build_ui()
	visibility_changed.connect(_on_visibility_changed)
	hide()


func _on_visibility_changed() -> void:
	# Scroll back to top every time the manual is opened
	if visible and _scroll != null:
		await get_tree().process_frame
		_scroll.scroll_vertical = 0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close()
	get_viewport().set_input_as_handled()


# ── Texture loading ───────────────────────────────────────────────────────────

func _load_textures() -> void:
	for path in PAGES:
		if ResourceLoader.exists(path):
			_textures.append(load(path) as Texture2D)
		else:
			push_warning("GameManualUI: missing page '%s' — using placeholder." % path)
			var ph := PlaceholderTexture2D.new()
			ph.size = Vector2i(PANEL_W - 24, 480)
			_textures.append(ph)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Dim overlay — click outside panel to close
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close()
	)
	add_child(overlay)

	# Centred panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -PANEL_W / 2.0
	panel.offset_right  =  PANEL_W / 2.0
	panel.offset_top    = -PANEL_H / 2.0
	panel.offset_bottom =  PANEL_H / 2.0
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# Title bar
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(title_bar)

	var title := Label.new()
	title.text = "Game Manual"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.pressed.connect(_close)
	title_bar.add_child(close_btn)

	# Single scroll container holding all pages stacked vertically
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	var pages_vbox := VBoxContainer.new()
	pages_vbox.add_theme_constant_override("separation", 0)
	pages_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages_vbox)

	var available_w: float = PANEL_W - 24.0

	for tex in _textures:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Set height proportional to width so the image isn't squashed
		if tex != null and tex.get_width() > 0:
			var aspect := float(tex.get_height()) / float(tex.get_width())
			rect.custom_minimum_size = Vector2(available_w, available_w * aspect)
		pages_vbox.add_child(rect)


func _close() -> void:
	hide()
	emit_signal("manual_closed")
