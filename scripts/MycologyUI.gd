# MycologyUI.gd
# Attach to a CanvasLayer node. Add this node to the "mycology_ui" group.
# Scene tree for this node:
#
# CanvasLayer  (MycologyUI.gd)
# └── PanelContainer  (id: Panel)
#     └── VBoxContainer
#         ├── HBoxContainer                    ← top row
#         │   ├── TextureRect  (id: MushroomImage)
#         │   └── VBoxContainer
#         │       ├── Label  (id: MushroomName)   ← e.g. "The Glowing Blue Mushroom"
#         │       └── Label  (id: MushroomSub)    ← e.g. "(Bioluminescent)"
#         ├── HSeparator
#         ├── Label  (id: PhaseLabel)             ← current phase instruction
#         ├── HSeparator
#         ├── Label  (id: DialogueText)           ← explorer dialogue / smell result
#         ├── HSeparator
#         ├── HBoxContainer  (id: ActionButtons)  ← EAT / LEAVE IT buttons (phase 2)
#         │   ├── Button  (id: EatButton)
#         │   └── Button  (id: LeaveButton)
#         └── Button  (id: CloseButton)           ← always visible

extends CanvasLayer

signal puzzle_resolved(mushroom_id: String, action: String, toxic: bool, effect: String)

# ── Node references ──────────────────────────────────────────────────────────
@onready var panel: PanelContainer       = $Panel
@onready var mushroom_image: TextureRect = $Panel/VBox/TopRow/MushroomImage
@onready var mushroom_name: Label        = $Panel/VBox/TopRow/Info/MushroomName
@onready var mushroom_sub: Label         = $Panel/VBox/TopRow/Info/MushroomSub
@onready var phase_label: Label          = $Panel/VBox/PhaseLabel
@onready var dialogue_text: Label        = $Panel/VBox/DialogueText
@onready var action_buttons: HBoxContainer = $Panel/VBox/ActionButtons
@onready var eat_button: Button          = $Panel/VBox/ActionButtons/EatButton
@onready var leave_button: Button        = $Panel/VBox/ActionButtons/LeaveButton
@onready var close_button: Button        = $Panel/VBox/CloseButton

# ── State ────────────────────────────────────────────────────────────────────
enum Phase { APPROACH, SMELL, RESULT }

var _current_data: Dictionary = {}
var _current_phase: Phase = Phase.APPROACH
var _smell_index: int = 0        # which smell was randomly assigned this run

const APPROACH_DIALOGUES: Array[String] = [
	"Explorer leans in cautiously... \"I can smell something.\"",
	"Explorer sniffs the air. \"Interesting... give me a moment.\"",
	"Explorer cups a hand to their nose. \"Let me get a better whiff.\"",
]

func _ready() -> void:
	add_to_group("mycology_ui")
	panel.visible = false
	action_buttons.visible = false
	eat_button.pressed.connect(_on_eat_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	close_button.pressed.connect(close_puzzle)
	# Make sure this UI doesn't pause the game — adjust if you use pause mode
	process_mode = Node.PROCESS_MODE_ALWAYS

# ── Public API ───────────────────────────────────────────────────────────────

## Called by MushroomPatch when player presses E
func open_puzzle(mushroom_data: Dictionary) -> void:
	_current_data = mushroom_data
	_current_phase = Phase.APPROACH

	# Randomly pick which smell this patch has (replayable variance)
	_smell_index = randi() % _current_data["smells"].size()

	# Populate static info
	mushroom_name.text = mushroom_data["visual_name"]
	mushroom_sub.text  = mushroom_data["subtitle"]

	var tex: Texture2D = load(mushroom_data["texture"]) as Texture2D
	if tex:
		mushroom_image.texture = tex
	else:
		push_warning("MycologyUI: Could not load texture: %s" % mushroom_data["texture"])

	_show_approach_phase()

	panel.visible = true
	# Optionally pause the game or capture mouse:
	# get_tree().paused = true
	# Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_puzzle() -> void:
	panel.visible = false
	action_buttons.visible = false
	_current_data = {}
	# get_tree().paused = false
	# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ── Phase transitions ────────────────────────────────────────────────────────

func _show_approach_phase() -> void:
	_current_phase = Phase.APPROACH
	phase_label.text = "📍 APPROACH THE PATCH"
	dialogue_text.text = APPROACH_DIALOGUES[randi() % APPROACH_DIALOGUES.size()]
	action_buttons.visible = false
	close_button.text = "Approach  [E]"
	# Re-wire close button to advance instead of closing
	close_button.pressed.disconnect(close_puzzle)
	close_button.pressed.connect(_on_approach_advance, CONNECT_ONE_SHOT)

func _on_approach_advance() -> void:
	close_button.pressed.connect(close_puzzle)  # restore
	_show_smell_phase()

func _show_smell_phase() -> void:
	_current_phase = Phase.SMELL
	var smell: Dictionary = _current_data["smells"][_smell_index]
	phase_label.text = "👃 SENSORY CUE DETECTED"
	dialogue_text.text = (
		"Explorer inhales deeply...\n\n"
		+ "\"It smells like... %s.\"\n\n"
		+ "What is your call, Explorer?" % smell["cue"]
	)
	action_buttons.visible = true
	close_button.text = "Cancel"

func _on_eat_pressed() -> void:
	_resolve("EAT")

func _on_leave_pressed() -> void:
	_resolve("LEAVE IT")

func _resolve(player_action: String) -> void:
	_current_phase = Phase.RESULT
	action_buttons.visible = false

	var smell: Dictionary = _current_data["smells"][_smell_index]
	var correct: bool = player_action == smell["action"]
	var species: String = smell["species"]
	var effect: String  = smell["effect"]
	var toxic: bool     = smell["toxic"]

	# Build result text
	var result_text: String
	if correct:
		if player_action == "EAT":
			result_text = (
				"✅  CORRECT — You eat the mushroom.\n\n"
				+ "It was a %s.\n%s" % [species, effect]
			)
		else:
			result_text = (
				"✅  CORRECT — You leave it alone.\n\n"
				+ "It was a %s.\n%s" % [species, effect]
			)
	else:
		if player_action == "EAT":
			result_text = (
				"❌  WRONG — You eat the mushroom.\n\n"
				+ "It was a %s.\n%s" % [species, effect]
			)
		else:
			result_text = (
				"❌  WRONG — You back away...\n\n"
				+ "It was a %s.\n%s" % [species, effect]
			)

	phase_label.text = "📋 RESULT"
	dialogue_text.text = result_text
	close_button.text = "Continue"

	# Emit signal so your game can apply health/status effects
	puzzle_resolved.emit(_current_data["id"], player_action, toxic, effect)

# ── Input fallback (ESC to close) ────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("ui_cancel"):
		if _current_phase == Phase.RESULT:
			close_puzzle()
		else:
			close_puzzle()  # or handle mid-puzzle cancel differently
