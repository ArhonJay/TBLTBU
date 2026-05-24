extends StaticBody3D

@export var simon_ui: CanvasLayer

var player_nearby := false
var ui_open := false
var puzzle_solved := false

var strikes := 0
var current_round := 1
var sequence := []
var player_sequence := []
var accepting_input := false
var playing_sequence := false

var button_data = {
	"BtnRed":    {"word": "RED",    "bg": "YELLOW"},
	"BtnBlue":   {"word": "BLUE",   "bg": "GREEN"},
	"BtnGreen":  {"word": "GREEN",  "bg": "RED"},
	"BtnYellow": {"word": "YELLOW", "bg": "BLUE"},
}

const TRANSLATION_TABLE = {
	"0_RED":    {"type": "bg",   "color": "BLUE"},
	"0_BLUE":   {"type": "word", "color": "GREEN"},
	"0_GREEN":  {"type": "bg",   "color": "YELLOW"},
	"0_YELLOW": {"type": "word", "color": "RED"},
	"1_RED":    {"type": "word", "color": "YELLOW"},
	"1_BLUE":   {"type": "bg",   "color": "RED"},
	"1_GREEN":  {"type": "word", "color": "BLUE"},
	"1_YELLOW": {"type": "bg",   "color": "GREEN"},
	"2_RED":    {"type": "bg",   "color": "GREEN"},
	"2_BLUE":   {"type": "word", "color": "RED"},
	"2_GREEN":  {"type": "bg",   "color": "BLUE"},
	"2_YELLOW": {"type": "word", "color": "YELLOW"},
}

const SPOKEN_COLORS = ["RED", "BLUE", "GREEN", "YELLOW"]

const COLOR_FREQ = {
	"RED":    330.0,
	"BLUE":   440.0,
	"GREEN":  550.0,
	"YELLOW": 660.0,
}

var status_label: Label
var strike_label: Label
var result_label: Label
var play_button: Button
var buttons = {}

var prompt_label: Label3D
var popup_label: Label3D

var puzzle_used := false

@onready var voice_player: AudioStreamPlayer = $VoicePlayer

func _ready():
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)

	prompt_label = Label3D.new()
	prompt_label.text = "Press E to interact"
	prompt_label.position = Vector3(0, 1.2, 0.1)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 48
	prompt_label.modulate = Color.WHITE
	prompt_label.outline_modulate = Color.BLACK
	prompt_label.outline_size = 8
	prompt_label.visible = false
	add_child(prompt_label)

	popup_label = Label3D.new()
	popup_label.text = ""
	popup_label.position = Vector3(0, 2.2, 0.1)
	popup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup_label.font_size = 64
	popup_label.outline_modulate = Color.BLACK
	popup_label.outline_size = 10
	popup_label.visible = false
	add_child(popup_label)

	if simon_ui == null:
		push_error("simon_says.gd: 'simon_ui' is not assigned!")
		return
	status_label = simon_ui.get_node("Control/PanelContainer/VBoxContainer/StatusLabel")
	strike_label = simon_ui.get_node("Control/PanelContainer/VBoxContainer/StrikeLabel")
	result_label = simon_ui.get_node("Control/PanelContainer/VBoxContainer/ResultLabel")
	play_button  = simon_ui.get_node("Control/PanelContainer/VBoxContainer/PlayButton")

	buttons = {
		"BtnRed":    simon_ui.get_node("Control/PanelContainer/VBoxContainer/Row1/BtnRed"),
		"BtnBlue":   simon_ui.get_node("Control/PanelContainer/VBoxContainer/Row1/BtnBlue"),
		"BtnGreen":  simon_ui.get_node("Control/PanelContainer/VBoxContainer/Row2/BtnGreen"),
		"BtnYellow": simon_ui.get_node("Control/PanelContainer/VBoxContainer/Row2/BtnYellow"),
	}

	_style_buttons()

	buttons["BtnRed"].pressed.connect(func(): _on_button_pressed("BtnRed"))
	buttons["BtnBlue"].pressed.connect(func(): _on_button_pressed("BtnBlue"))
	buttons["BtnGreen"].pressed.connect(func(): _on_button_pressed("BtnGreen"))
	buttons["BtnYellow"].pressed.connect(func(): _on_button_pressed("BtnYellow"))
	play_button.pressed.connect(_on_play_pressed)
	simon_ui.get_node("Control/CloseButton").pressed.connect(_close_ui)

	simon_ui.visible = false
	_generate_sequence()

func _show_popup(msg: String, color: Color):
	popup_label.text = msg
	popup_label.modulate = color
	popup_label.position = Vector3(0, 2.2, 0.1)
	popup_label.visible = true
	var tween = create_tween()
	tween.tween_property(popup_label, "position", Vector3(0, 3.2, 0.1), 1.8)
	tween.parallel().tween_property(popup_label, "modulate:a", 0.0, 1.8)
	await tween.finished
	popup_label.visible = false
	popup_label.modulate = color

func _style_buttons():
	for btn_name in button_data:
		var btn = buttons[btn_name]
		var data = button_data[btn_name]

		btn.text = data.word

		var all_colors = ["RED", "BLUE", "GREEN", "YELLOW"]
		var remaining = []
		for c in all_colors:
			if c != data.word and c != data.bg:
				remaining.append(c)
		var ink_color_name = remaining[0]
		var ink_color = _name_to_color(ink_color_name)

		btn.add_theme_color_override("font_color", ink_color)
		btn.add_theme_color_override("font_color_hover", ink_color.lightened(0.3))
		btn.add_theme_color_override("font_color_pressed", ink_color.darkened(0.2))

		var bg = StyleBoxFlat.new()
		bg.bg_color = _name_to_color(data.bg).darkened(0.3)
		bg.corner_radius_top_left = 8
		bg.corner_radius_top_right = 8
		bg.corner_radius_bottom_left = 8
		bg.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", bg)

		var bg_hover = bg.duplicate()
		bg_hover.bg_color = _name_to_color(data.bg).darkened(0.1)
		btn.add_theme_stylebox_override("hover", bg_hover)

func _name_to_color(name: String) -> Color:
	match name:
		"RED":    return Color(1.0, 0.2, 0.2)
		"BLUE":   return Color(0.2, 0.4, 1.0)
		"GREEN":  return Color(0.1, 0.8, 0.1)
		"YELLOW": return Color(1.0, 1.0, 0.1)
	return Color.WHITE

func _get_correct_button_for(heard_color: String) -> String:
	var strike_key = str(min(strikes, 2))
	var rule = TRANSLATION_TABLE[strike_key + "_" + heard_color]

	for btn_name in button_data:
		var data = button_data[btn_name]
		if rule.type == "word" and data.word == rule.color:
			return btn_name
		elif rule.type == "bg" and data.bg == rule.color:
			return btn_name
	return ""

func _generate_sequence():
	sequence.clear()
	for i in range(3):
		sequence.append(SPOKEN_COLORS[randi() % 4])
	print("=== SIMON SEQUENCE ===")
	for i in range(sequence.size()):
		print("Step ", i+1, ": ", sequence[i])
	_print_correct_answers()

func _print_correct_answers():
	print("=== CORRECT BUTTONS (strikes=", strikes, ") ===")
	for i in range(current_round):
		var heard = sequence[i]
		var correct = _get_correct_button_for(heard)
		var rule = TRANSLATION_TABLE[str(min(strikes,2)) + "_" + heard]
		print("Heard ", heard, " → press ", rule.type.to_upper(), " ", rule.color, " (", correct, ")")

func _on_play_pressed():
	if playing_sequence or accepting_input:
		return
	play_button.disabled = true
	accepting_input = false
	player_sequence.clear()
	result_label.text = ""
	_play_sequence()

func _play_sequence():
	playing_sequence = true
	status_label.text = "Listen to the sequence..."
	_set_buttons_disabled(true)

	for i in range(current_round):
		var color = sequence[i]
		status_label.text = "Hearing: " + color + "..."
		_speak_color(color)
		await get_tree().create_timer(1.0).timeout

	playing_sequence = false
	accepting_input = true
	_set_buttons_disabled(false)
	status_label.text = "Press the correct buttons! (" + str(current_round) + " presses needed)"

func _speak_color(color: String):
	var freq = COLOR_FREQ[color]
	var sample_rate = 44100

	var patterns = {
		"RED":    [{"f": freq, "d": 0.15}, {"f": freq * 1.2, "d": 0.15}],
		"BLUE":   [{"f": freq, "d": 0.1}, {"f": freq * 0.8, "d": 0.2}, {"f": freq * 1.1, "d": 0.1}],
		"GREEN":  [{"f": freq * 1.1, "d": 0.1}, {"f": freq, "d": 0.15}, {"f": freq * 0.9, "d": 0.1}, {"f": freq * 1.2, "d": 0.1}],
		"YELLOW": [{"f": freq * 0.9, "d": 0.1}, {"f": freq * 1.1, "d": 0.1}, {"f": freq, "d": 0.1}, {"f": freq * 1.2, "d": 0.1}, {"f": freq * 0.8, "d": 0.1}],
	}

	var pattern = patterns[color]
	var gap_samples = int(sample_rate * 0.05)
	var total_samples = 0
	for seg in pattern:
		total_samples += int(sample_rate * seg.d) + gap_samples

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = sample_rate

	var data = PackedByteArray()
	data.resize(total_samples * 2)

	var pos = 0
	for seg in pattern:
		var seg_samples = int(sample_rate * seg.d)
		var fade = int(sample_rate * 0.01)
		for i in range(seg_samples):
			var t = float(i) / sample_rate
			var amp = 1.0
			if i < fade:
				amp = float(i) / fade
			elif i > seg_samples - fade:
				amp = float(seg_samples - i) / fade
			var sample = int(sin(2.0 * PI * seg.f * t) * 28000.0 * amp)
			sample = clamp(sample, -32768, 32767)
			data[(pos + i) * 2]     = sample & 0xFF
			data[(pos + i) * 2 + 1] = (sample >> 8) & 0xFF
		pos += seg_samples
		for i in range(gap_samples):
			data[(pos + i) * 2]     = 0
			data[(pos + i) * 2 + 1] = 0
		pos += gap_samples

	stream.data = data
	voice_player.stream = stream
	voice_player.play()

func _on_button_pressed(btn_name: String):
	if not accepting_input:
		return

	var step = player_sequence.size()
	var heard = sequence[step]
	var correct_btn = _get_correct_button_for(heard)

	if btn_name == correct_btn:
		player_sequence.append(btn_name)
		result_label.text = "✓ Correct!"
		result_label.add_theme_color_override("font_color", Color.GREEN)

		if player_sequence.size() == current_round:
			accepting_input = false
			await get_tree().create_timer(0.8).timeout

			if current_round >= 3:
				result_label.text = "✓ MODULE DISARMED!"
				result_label.add_theme_color_override("font_color", Color.GREEN)
				status_label.text = "Simon Says is disarmed!"
				puzzle_solved = true
				puzzle_used = true
				prompt_label.visible = false
				play_button.disabled = true
				_set_buttons_disabled(true)
				NetworkManager.adjust_world_timer(60)
				_close_ui()
				_show_popup("+60 seconds", Color(0.1, 1.0, 0.1))

				# ── Notify objective tracker ──────────────────────────────────
				ObjectiveManager.register_simon_solved()
			else:
				current_round += 1
				player_sequence.clear()
				_update_strike_label()
				_print_correct_answers()
				result_label.text = "Round " + str(current_round) + "! Sequence is longer now."
				play_button.disabled = false
				status_label.text = "Press PLAY for round " + str(current_round)
	else:
		strikes += 1
		player_sequence.clear()
		accepting_input = false
		_update_strike_label()

		if strikes >= 3:
			result_label.text = "✗ Too many strikes! Puzzle locked."
			result_label.add_theme_color_override("font_color", Color.RED)
			status_label.text = "Simon Says is locked out!"
			accepting_input = false
			puzzle_used = true
			prompt_label.visible = false
			play_button.disabled = true
			_set_buttons_disabled(true)
			NetworkManager.adjust_world_timer(-30)
			_close_ui()
			_show_popup("-30 seconds", Color(1.0, 0.2, 0.2))
		else:
			result_label.text = "✗ Wrong! Strike " + str(strikes) + ". Try again."
			result_label.add_theme_color_override("font_color", Color.RED)
			_print_correct_answers()
			await get_tree().create_timer(1.0).timeout
			play_button.disabled = false
			status_label.text = "Press PLAY to hear the sequence again"

func _reset_puzzle():
	strikes = 0
	current_round = 1
	player_sequence.clear()
	sequence.clear()
	_generate_sequence()
	_update_strike_label()
	result_label.text = "Puzzle reset!"
	play_button.disabled = false
	status_label.text = "Press PLAY to hear the sequence"

func _update_strike_label():
	strike_label.text = "Strikes: " + str(strikes) + " | Round: " + str(current_round) + " / 3"

func _set_buttons_disabled(disabled: bool):
	for btn_name in buttons:
		buttons[btn_name].disabled = disabled

func _open_ui():
	if puzzle_solved or puzzle_used:
		return
	ui_open = true
	simon_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_strike_label()
	if not accepting_input and not playing_sequence:
		player_sequence.clear()
		result_label.text = ""
		play_button.disabled = false
		_set_buttons_disabled(true)
		status_label.text = "Press PLAY to hear the sequence"

func _close_ui():
	ui_open = false
	simon_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = true
		if not puzzle_used:
			prompt_label.visible = true

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = false
		prompt_label.visible = false

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open:
			_open_ui()
		elif ui_open:
			_close_ui()
