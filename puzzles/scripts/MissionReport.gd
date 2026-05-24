extends CanvasLayer

# ─────────────────────────────────────────────────────────────────────────────
#  MissionReport.gd
#  Spawned by GameEndSequence after the ending video.
#
#  GameEndSequence calls setup(stats) BEFORE _ready() builds the UI,
#  so both peers display the same data regardless of local ObjectiveManager.
# ─────────────────────────────────────────────────────────────────────────────

var _cover : ColorRect
var _stats : Dictionary = {}


func setup(stats: Dictionary) -> void:
	_stats = stats


func get_cover() -> ColorRect:
	return _cover


func _ready() -> void:
	layer = 30
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()


func _build_ui() -> void:
	# Use synced stats if available, fall back to ObjectiveManager (solo / editor).
	var chests_done    : int  = _stats.get("chests_done",    ObjectiveManager.chests_done)
	var simon_done     : int  = _stats.get("simon_done",     ObjectiveManager.simon_done)
	var mushrooms_done : int  = _stats.get("mushrooms_done", ObjectiveManager.mushrooms_done)
	var locker_solved  : bool = _stats.get("locker_solved",  ObjectiveManager.locker_solved)
	var elapsed        : String = _stats.get("elapsed",      ObjectiveManager.get_elapsed_formatted())
	var TARGET_CHESTS  : int  = _stats.get("TARGET_CHESTS",  ObjectiveManager.TARGET_CHESTS)
	var TARGET_SIMON   : int  = _stats.get("TARGET_SIMON",   ObjectiveManager.TARGET_SIMON)
	var TARGET_MUSHROOMS: int = _stats.get("TARGET_MUSHROOMS", ObjectiveManager.TARGET_MUSHROOMS)

	# ── Dark backdrop ─────────────────────────────────────────────────────────
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.04, 0.07, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_add_background_dots(backdrop)

	# ── Scroll container ──────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	center.custom_minimum_size   = Vector2(0, 720)
	scroll.add_child(center)

	# ── Main card ─────────────────────────────────────────────────────────────
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color              = Color(0.09, 0.09, 0.14, 0.98)
	card_style.border_color          = Color(0.75, 0.60, 0.20, 0.85)
	card_style.border_width_top      = 2
	card_style.border_width_bottom   = 2
	card_style.border_width_left     = 2
	card_style.border_width_right    = 2
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left   = 36.0
	card_style.content_margin_right  = 36.0
	card_style.content_margin_top    = 28.0
	card_style.content_margin_bottom = 28.0
	card_style.shadow_color          = Color(0, 0, 0, 0.55)
	card_style.shadow_size           = 20
	card_style.shadow_offset         = Vector2(0, 6)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	_add_banner(vbox)
	_add_spacer(vbox, 14)
	_add_time_card(vbox, elapsed)
	_add_spacer(vbox, 18)
	_add_divider(vbox)
	_add_spacer(vbox, 16)

	var section_lbl := _make_label("MISSION SUMMARY", 11, Color(0.75, 0.60, 0.20, 0.9))
	section_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(section_lbl)
	_add_spacer(vbox, 10)

	_add_stat_row(vbox, "🔓  Chests Picklocked",
		"%d / %d" % [chests_done, TARGET_CHESTS],
		float(chests_done) / float(TARGET_CHESTS), Color(0.95, 0.75, 0.20))
	_add_spacer(vbox, 8)
	_add_stat_row(vbox, "🎵  Simon Says Decoded",
		"%d / %d" % [simon_done, TARGET_SIMON],
		float(simon_done) / float(TARGET_SIMON), Color(0.35, 0.75, 1.0))
	_add_spacer(vbox, 8)
	_add_stat_row(vbox, "🍄  Healthy Mushrooms Eaten",
		"%d / %d" % [mushrooms_done, TARGET_MUSHROOMS],
		float(mushrooms_done) / float(TARGET_MUSHROOMS), Color(0.35, 0.90, 0.45))
	_add_spacer(vbox, 8)
	_add_stat_row(vbox, "🔐  Facility Unlocked",
		"YES" if locker_solved else "NO",
		1.0 if locker_solved else 0.0, Color(0.90, 0.45, 0.90))
	_add_spacer(vbox, 16)

	_add_divider(vbox)
	_add_spacer(vbox, 14)
	_add_completion_badge(vbox, chests_done, simon_done, mushrooms_done, locker_solved,
		TARGET_CHESTS, TARGET_SIMON, TARGET_MUSHROOMS)
	_add_spacer(vbox, 18)
	_add_menu_button(vbox)

	_animate_children(vbox)

	# ── Cover rect — added LAST so it sits above everything ───────────────────
	_cover = ColorRect.new()
	_cover.color        = Color(0, 0, 0, 1)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)


# ─────────────────────────────────────────────────────────────────────────────
#  Menu button
# ─────────────────────────────────────────────────────────────────────────────
func _add_menu_button(parent: VBoxContainer) -> void:
	var btn_center := CenterContainer.new()
	parent.add_child(btn_center)

	var btn := Button.new()
	btn.text                = "  RETURN TO MAIN MENU  "
	btn.custom_minimum_size = Vector2(260, 52)
	btn.focus_mode          = Control.FOCUS_NONE

	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.75, 0.60, 0.20, 0.95)
	sty.set_corner_radius_all(10)
	sty.content_margin_left = 24.0; sty.content_margin_right  = 24.0
	sty.content_margin_top  = 12.0; sty.content_margin_bottom = 12.0
	btn.add_theme_stylebox_override("normal", sty)

	var sty_h := sty.duplicate(); sty_h.bg_color = Color(0.90, 0.74, 0.28, 1.0)
	btn.add_theme_stylebox_override("hover", sty_h)

	var sty_p := sty.duplicate(); sty_p.bg_color = Color(0.60, 0.48, 0.14, 1.0)
	btn.add_theme_stylebox_override("pressed", sty_p)

	btn.add_theme_color_override("font_color",         Color(0.10, 0.08, 0.03, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(0.08, 0.06, 0.02, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.06, 0.04, 0.01, 1.0))
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_menu_pressed)
	btn_center.add_child(btn)


func _on_menu_pressed() -> void:
	if _cover:
		_cover.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween := create_tween()
		tween.tween_property(_cover, "color:a", 1.0, 0.5)
		tween.tween_callback(_do_scene_change)
	else:
		_do_scene_change()


func _do_scene_change() -> void:
	var explorer := get_tree().get_first_node_in_group("explorer")
	if explorer and explorer.has_method("_go_to_main_menu"):
		explorer._go_to_main_menu.rpc()
		return

	var scientist := get_tree().get_first_node_in_group("scientist")
	if scientist and scientist.has_method("_go_to_main_menu"):
		scientist._go_to_main_menu.rpc()
		return

	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("reset"):
		nm.reset()
	get_tree().change_scene_to_file("res://menu/MainMenu.tscn")


# ─────────────────────────────────────────────────────────────────────────────
#  UI helpers
# ─────────────────────────────────────────────────────────────────────────────
func _add_banner(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	parent.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "🏆"
	icon_lbl.add_theme_font_size_override("font_size", 28)
	hbox.add_child(icon_lbl)

	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(title_vbox)

	var title := _make_label("MISSION COMPLETE", 24, Color(0.95, 0.82, 0.25, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_vbox.add_child(title)

	var sub := _make_label("EXPEDITION DEBRIEF", 12, Color(0.65, 0.62, 0.55, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_vbox.add_child(sub)


func _add_time_card(parent: VBoxContainer, time_str: String) -> void:
	var card := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.13, 0.12, 0.20, 1.0)
	sty.border_color = Color(0.55, 0.45, 0.15, 0.6)
	sty.border_width_bottom = 2
	sty.set_corner_radius_all(10)
	sty.content_margin_left = 24.0; sty.content_margin_right  = 24.0
	sty.content_margin_top  = 14.0; sty.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", sty)
	parent.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	card.add_child(hbox)

	hbox.add_child(_make_label("⏱", 22, Color(0.75, 0.60, 0.20, 1.0)))

	var label_vbox := VBoxContainer.new()
	label_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(label_vbox)

	label_vbox.add_child(_make_label("COMPLETION TIME", 10, Color(0.55, 0.53, 0.48, 0.85)))
	label_vbox.add_child(_make_label(time_str, 28, Color(0.96, 0.92, 0.75, 1.0)))


func _add_stat_row(parent: VBoxContainer, label: String, value: String,
		progress: float, accent: Color) -> void:
	var row_panel := PanelContainer.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color     = Color(accent.r, accent.g, accent.b, 0.07)
	sty.border_color = Color(accent.r, accent.g, accent.b, 0.25)
	sty.border_width_left = 3
	sty.set_corner_radius_all(8)
	sty.content_margin_left = 14.0; sty.content_margin_right  = 14.0
	sty.content_margin_top  =  9.0; sty.content_margin_bottom =  9.0
	row_panel.add_theme_stylebox_override("panel", sty)
	parent.add_child(row_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	row_panel.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)

	var name_lbl := _make_label(label, 14, Color(0.92, 0.90, 0.85, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)
	top.add_child(_make_label(value, 14, accent))

	var bar_bg := PanelContainer.new()
	var bar_sty := StyleBoxFlat.new()
	bar_sty.bg_color = Color(0.18, 0.18, 0.24, 1.0)
	bar_sty.set_corner_radius_all(4)
	bar_bg.add_theme_stylebox_override("panel", bar_sty)
	bar_bg.custom_minimum_size = Vector2(0, 6)
	col.add_child(bar_bg)

	var fill := ColorRect.new()
	fill.color  = accent
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.scale.x = 0.0
	bar_bg.add_child(fill)

	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(fill, "scale:x", clamp(progress, 0.0, 1.0), 0.8).set_trans(Tween.TRANS_CUBIC)


func _add_completion_badge(parent: VBoxContainer,
		chests_done: int, simon_done: int, mushrooms_done: int, locker_solved: bool,
		target_chests: int, target_simon: int, target_mushrooms: int) -> void:
	var total_tasks : int = target_chests + target_simon + target_mushrooms + 1
	var done_tasks  : int = chests_done + simon_done + mushrooms_done + (1 if locker_solved else 0)
	var pct         : int = int(float(done_tasks) / float(total_tasks) * 100.0)

	var grade : String
	var grade_color : Color
	if pct == 100:   grade = "S"; grade_color = Color(1.0,  0.88, 0.20)
	elif pct >= 80:  grade = "A"; grade_color = Color(0.35, 0.90, 0.45)
	elif pct >= 60:  grade = "B"; grade_color = Color(0.35, 0.75, 1.0)
	else:            grade = "C"; grade_color = Color(0.90, 0.55, 0.25)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 32)
	parent.add_child(hbox)

	var bubble := PanelContainer.new()
	var bsty := StyleBoxFlat.new()
	bsty.bg_color     = Color(grade_color.r, grade_color.g, grade_color.b, 0.15)
	bsty.border_color = grade_color
	bsty.border_width_top = 2; bsty.border_width_bottom = 2
	bsty.border_width_left = 2; bsty.border_width_right  = 2
	bsty.set_corner_radius_all(14)
	bsty.content_margin_left = 24.0; bsty.content_margin_right  = 24.0
	bsty.content_margin_top  = 10.0; bsty.content_margin_bottom = 10.0
	bubble.add_theme_stylebox_override("panel", bsty)
	hbox.add_child(bubble)
	bubble.add_child(_make_label(grade, 34, grade_color))

	var score_vbox := VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(score_vbox)
	score_vbox.add_child(_make_label("OVERALL SCORE", 10, Color(0.55, 0.53, 0.48, 0.85)))
	score_vbox.add_child(_make_label("%d%%" % pct, 22, grade_color))
	score_vbox.add_child(_make_label("%d of %d objectives completed" % [done_tasks, total_tasks],
		12, Color(0.70, 0.68, 0.62, 0.85)))


func _add_background_dots(parent: ColorRect) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(60):
		var dot := ColorRect.new()
		var sz  := rng.randf_range(2.0, 5.0)
		dot.custom_minimum_size = Vector2(sz, sz)
		dot.color = Color(rng.randf_range(0.5, 1.0), rng.randf_range(0.4, 0.8),
			rng.randf_range(0.1, 0.4), rng.randf_range(0.06, 0.18))
		dot.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		parent.add_child(dot)


func _animate_children(vbox: VBoxContainer) -> void:
	var delay := 0.1
	for child in vbox.get_children():
		child.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(delay)
		t.tween_property(child, "modulate:a", 1.0, 0.4)
		delay += 0.07


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _add_spacer(parent: VBoxContainer, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)


func _add_divider(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.55, 0.45, 0.15, 0.35)
	sty.content_margin_top = 1.0; sty.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sty)
	parent.add_child(sep)
