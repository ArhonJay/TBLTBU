extends CanvasLayer

# --- DATA ---
const HOTBAR_SIZE = 3
const BAG_SIZE = 4

var hotbar_items: Array = []
var bag_items: Array = []
var selected_slot: int = 0
var bag_open: bool = false

# --- NODE REFS ---
@onready var hotbar: HBoxContainer = $Control/HotbarAnchor/Hotbar
@onready var bag_panel: PanelContainer = $Control/BagPanel
@onready var bag_item_list: VBoxContainer = $Control/BagPanel/MarginContainer/VBox/ItemList
@onready var bag_slot_node: PanelContainer = $Control/HotbarAnchor/Hotbar/BagSlot
@onready var capacity_label: Label = $Control/BagPanel/MarginContainer/VBox/CapacityLabel
@onready var bag_mesh: MeshInstance3D = $Control/HotbarAnchor/Hotbar/BagSlot/ViewportContainer/SubViewport/BagMeshInstance

var hotbar_slot_nodes: Array = []
var bag_slot_nodes: Array = []

# --- STYLES for bag button ---
var _style_bag_normal: StyleBoxFlat
var _style_bag_open: StyleBoxFlat

func _ready():
	hotbar_items.resize(HOTBAR_SIZE)
	hotbar_items.fill(null)
	bag_items.resize(BAG_SIZE)
	bag_items.fill(null)

	bag_panel.visible = false
	_build_slot_refs()
	_build_bag_styles()
	# ─── STARTING INVENTORY ──────────────────────────────────────────
		# Force the flashlight dictionary directly into Slot 1 (index 0)
	hotbar_items[0] = {
		"id": "lamp",
		"name": "Flashlight",
		"type": "tool",
		"icon": preload("res://assets/survival/flashlight.png") # <--- MAKE SURE THIS PATH MATCHES YOUR PNG!
	}
		# ─────────────────────────────────────────────────────────────────
	_refresh_hotbar()
	_refresh_bag()
	_update_selection()

func _build_bag_styles():
	_style_bag_normal = StyleBoxFlat.new()
	_style_bag_normal.bg_color = Color(0.12, 0.09, 0.04, 0.8)
	_style_bag_normal.set_corner_radius_all(8)
	_style_bag_normal.border_width_top = 2; _style_bag_normal.border_width_bottom = 2
	_style_bag_normal.border_width_left = 2; _style_bag_normal.border_width_right = 2
	_style_bag_normal.border_color = Color(0.75, 0.55, 0.15, 0.7)

	_style_bag_open = StyleBoxFlat.new()
	_style_bag_open.bg_color = Color(0.5, 0.33, 0.05, 0.6)
	_style_bag_open.set_corner_radius_all(8)
	_style_bag_open.border_width_top = 2; _style_bag_open.border_width_bottom = 2
	_style_bag_open.border_width_left = 2; _style_bag_open.border_width_right = 2
	_style_bag_open.border_color = Color(1.0, 0.78, 0.2, 1.0)

func _build_slot_refs():
	hotbar_slot_nodes.clear()
	for i in HOTBAR_SIZE:
		hotbar_slot_nodes.append(hotbar.get_node("Slot%d" % (i + 1)))
	bag_slot_nodes.clear()
	for i in BAG_SIZE:
		bag_slot_nodes.append(bag_item_list.get_node("BagSlot%d" % (i + 1)))

# --- PUBLIC API ---
func add_item(item: Dictionary) -> bool:
	for i in HOTBAR_SIZE:
		if hotbar_items[i] == null:
			hotbar_items[i] = item
			_refresh_hotbar()
			return true
	for i in BAG_SIZE:
		if bag_items[i] == null:
			bag_items[i] = item
			_refresh_bag()
			return true
	return false

func get_selected_item() -> Variant:
	return hotbar_items[selected_slot]

func remove_selected_item():
	hotbar_items[selected_slot] = null
	_refresh_hotbar()

func clear_all():
	hotbar_items.fill(null)
	bag_items.fill(null)
	_refresh_hotbar()
	_refresh_bag()
	bag_panel.visible = false
	bag_open = false
	selected_slot = 0
	_update_selection()
	_update_bag_slot_highlight()

# --- INPUT ---
func _process(delta: float) -> void:
	if bag_mesh:
		bag_mesh.rotation_degrees.y += 40.0 * delta

func _input(event):
	if not get_parent().is_multiplayer_authority():
		return
	if event.is_action_pressed("inventory_1"):
		selected_slot = 0
		_update_selection()
	elif event.is_action_pressed("inventory_2"):
		selected_slot = 1
		_update_selection()
	elif event.is_action_pressed("inventory_3"):
		selected_slot = 2
		_update_selection()
	elif event.is_action_pressed("inventory_bag"):
		_toggle_bag()

# --- BAG TOGGLE ---
func _toggle_bag():
	bag_open = not bag_open
	bag_panel.visible = bag_open
	_update_bag_slot_highlight()
	if bag_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_bag_slot_highlight():
	bag_slot_node.add_theme_stylebox_override("panel",
		_style_bag_open if bag_open else _style_bag_normal)

# --- SLOT CLICK from bag panel ---
func _on_bag_slot_clicked(index: int):
	if bag_items[index] == null:
		return
	for i in HOTBAR_SIZE:
		if hotbar_items[i] == null:
			hotbar_items[i] = bag_items[index]
			bag_items[index] = null
			_refresh_hotbar()
			_refresh_bag()
			return
	var tmp = hotbar_items[selected_slot]
	hotbar_items[selected_slot] = bag_items[index]
	bag_items[index] = tmp
	_refresh_hotbar()
	_refresh_bag()

# --- REFRESH UI ---
func _refresh_hotbar():
	for i in HOTBAR_SIZE:
		var slot_node = hotbar_slot_nodes[i]
		var icon_rect: TextureRect = slot_node.get_node("Icon")
		var count_label: Label = slot_node.get_node("Count")
		var item = hotbar_items[i]
		if item != null:
			icon_rect.texture = item.get("icon", null)
			icon_rect.visible = icon_rect.texture != null
			var count = item.get("count", 1)
			count_label.text = str(count) if count > 1 else ""
			count_label.visible = count > 1
		else:
			icon_rect.texture = null
			icon_rect.visible = false
			count_label.visible = false

func _refresh_bag():
	var filled = 0
	for i in BAG_SIZE:
		var slot_node = bag_slot_nodes[i]
		var icon_bg = slot_node.get_node("HBox/IconBG")
		var icon_rect: TextureRect = icon_bg.get_node("Icon")
		var empty_icon: Label = icon_bg.get_node("EmptyIcon")
		var name_label: Label = slot_node.get_node("HBox/InfoVBox/NameLabel")
		var sub_label: Label = slot_node.get_node("HBox/InfoVBox/SubLabel")
		var count_label: Label = slot_node.get_node("HBox/Count")
		var item = bag_items[i]
		if item != null:
			filled += 1
			icon_rect.texture = item.get("icon", null)
			icon_rect.visible = icon_rect.texture != null
			empty_icon.visible = icon_rect.texture == null
			name_label.text = item.get("name", "Unknown")
			name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82, 1))
			name_label.visible = true
			var desc = item.get("description", item.get("type", ""))
			sub_label.text = desc
			sub_label.visible = desc != ""
			var count = item.get("count", 1)
			count_label.text = "x%d" % count if count > 1 else ""
			count_label.visible = count > 1
		else:
			icon_rect.texture = null
			icon_rect.visible = false
			empty_icon.visible = true
			name_label.text = "Empty"
			name_label.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38, 0.5))
			name_label.visible = true
			sub_label.visible = false
			count_label.visible = false
	capacity_label.text = "%d / %d items" % [filled, BAG_SIZE]

func _update_selection():
	for i in HOTBAR_SIZE:
		hotbar_slot_nodes[i].add_theme_stylebox_override("panel", _make_slot_style(i == selected_slot))

# --- STYLE HELPERS ---
func _make_slot_style(selected: bool) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	if selected:
		s.bg_color = Color(0.85, 0.78, 0.3, 0.3)
		s.border_width_top = 2; s.border_width_bottom = 2
		s.border_width_left = 2; s.border_width_right = 2
		s.border_color = Color(1.0, 0.88, 0.3, 1.0)
	else:
		s.bg_color = Color(0.07, 0.07, 0.09, 0.72)
		s.border_width_top = 1; s.border_width_bottom = 1
		s.border_width_left = 1; s.border_width_right = 1
		s.border_color = Color(0.5, 0.5, 0.55, 0.4)
	s.set_corner_radius_all(8)
	return s
