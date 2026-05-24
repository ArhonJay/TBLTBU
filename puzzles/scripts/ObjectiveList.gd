extends CanvasLayer

# ─────────────────────────────────────────────────────────────────────────────
#  ObjectiveList.gd
#
#  Attach to the ObjectiveList CanvasLayer inside the Explorer scene.
#  The Panel is anchored to the TOP-LEFT corner.
#
#  Required scene tree:
#
#  ObjectiveList  (CanvasLayer, layer = 10)
#  └── Panel  (PanelContainer)   ← anchored top-left
#      └── VBox  (VBoxContainer)
#          ├── Header  (Label)
#          ├── Separator  (HSeparator)
#          ├── Phase1Container  (VBoxContainer)
#          │   ├── ChestRow    (HBoxContainer)
#          │   │   ├── ChestCheck   (Label)
#          │   │   └── ChestLabel   (Label)
#          │   ├── SimonRow    (HBoxContainer)
#          │   │   ├── SimonCheck   (Label)
#          │   │   └── SimonLabel   (Label)
#          │   └── MushroomRow (HBoxContainer)
#          │       ├── MushroomCheck (Label)
#          │       └── MushroomLabel (Label)
#          └── Phase2Container (VBoxContainer)
#              └── LabRow      (HBoxContainer)
#                  ├── LabCheck  (Label)
#                  └── LabLabel  (Label)
# ─────────────────────────────────────────────────────────────────────────────

@onready var phase1_container : VBoxContainer = $Panel/VBox/Phase1Container
@onready var phase2_container : VBoxContainer = $Panel/VBox/Phase2Container

@onready var chest_label    : Label = $Panel/VBox/Phase1Container/ChestRow/ChestLabel
@onready var chest_check    : Label = $Panel/VBox/Phase1Container/ChestRow/ChestCheck
@onready var simon_label    : Label = $Panel/VBox/Phase1Container/SimonRow/SimonLabel
@onready var simon_check    : Label = $Panel/VBox/Phase1Container/SimonRow/SimonCheck
@onready var mushroom_label : Label = $Panel/VBox/Phase1Container/MushroomRow/MushroomLabel
@onready var mushroom_check : Label = $Panel/VBox/Phase1Container/MushroomRow/MushroomCheck

@onready var lab_label : Label = $Panel/VBox/Phase2Container/LabRow/LabLabel
@onready var lab_check : Label = $Panel/VBox/Phase2Container/LabRow/LabCheck


func _ready() -> void:
	# Only show for the local multiplayer authority (the owning explorer)
	var explorer := get_parent()
	if explorer.has_method("is_multiplayer_authority"):
		if not explorer.is_multiplayer_authority():
			hide()
			return

	ObjectiveManager.objectives_updated.connect(_refresh_ui)
	ObjectiveManager.phase_changed.connect(_on_phase_changed)

	phase2_container.visible = false
	phase1_container.visible = true

	_refresh_ui()


# ── Refresh display ───────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	var om := ObjectiveManager

	if om.get_phase() == 1:
		var c_done : int = om.chests_done
		var s_done : int = om.simon_done
		var m_done : int = om.mushrooms_done

		chest_label.text    = "Picklock Chests %d/%d"                      % [c_done, om.TARGET_CHESTS]
		simon_label.text    = "Decode Simon Says %d/%d"                    % [s_done, om.TARGET_SIMON]
		mushroom_label.text = "Successfully Eat a Healthy Mushroom %d/%d"  % [m_done, om.TARGET_MUSHROOMS]

		chest_check.text    = "☑" if c_done >= om.TARGET_CHESTS    else "☐"
		simon_check.text    = "☑" if s_done >= om.TARGET_SIMON     else "☐"
		mushroom_check.text = "☑" if m_done >= om.TARGET_MUSHROOMS else "☐"

		_set_row_complete(chest_label,    chest_check,    c_done >= om.TARGET_CHESTS)
		_set_row_complete(simon_label,    simon_check,    s_done >= om.TARGET_SIMON)
		_set_row_complete(mushroom_label, mushroom_check, m_done >= om.TARGET_MUSHROOMS)

	else:
		if om.locker_solved:
			lab_label.text = "Facility Opened!"
			lab_check.text = "☑"
			_set_row_complete(lab_label, lab_check, true)
		else:
			lab_label.text = "Find the laboratory and acquire a\nkeycard to open the facility."
			lab_check.text = "☐"
			_set_row_complete(lab_label, lab_check, false)


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == 2:
		var tween := create_tween()
		tween.tween_property(phase1_container, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func():
			phase1_container.visible = false
			phase2_container.visible = true
			phase2_container.modulate.a = 0.0
		)
		tween.tween_property(phase2_container, "modulate:a", 1.0, 0.5)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _set_row_complete(text_label: Label, check_label: Label, done: bool) -> void:
	var completed_color := Color(0.45, 0.85, 0.45, 0.6)
	var active_color    := Color(0.95, 0.93, 0.85, 1.0)
	var check_done_color:= Color(0.35, 0.90, 0.35, 1.0)

	text_label.modulate  = completed_color if done else active_color
	check_label.modulate = check_done_color if done else active_color
