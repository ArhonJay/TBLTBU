extends StaticBody3D

@export var radio_ui: CanvasLayer

var player_nearby := false
var ui_open := false
var puzzle_solved := false
var tones_playing := false

# tone data
const PITCHES = ["High", "Mid", "Low"]
const DURATIONS = ["Short", "Long"]

# translation table from manual
const TONE_TABLE = {
	"High_Short": "2",
	"High_Long": "1",
	"Mid_Short": "4",
	"Mid_Long": "3",
	"Low_Short": "6",
	"Low_Long": "5"
}

# pitch frequencies for audio generation
const PITCH_FREQ = {
	"High": 880.0,
	"Mid": 440.0,
	"Low": 220.0
}

# duration in seconds
const DURATION_TIME = {
	"Short": 0.4,
	"Long": 1.0
}

var generated_tones = []  # list of {pitch, duration}
var correct_code := ""

# UI refs
var status_label: Label
var tone_labels: Array = []
var play_button: Button
var code_input: LineEdit
var result_label: Label
var prompt_label: Label3D


@onready var tone_player: AudioStreamPlayer = $TonePlayer

func _ready():
	$InteractionZone.body_entered.connect(_on_body_entered)
	$InteractionZone.body_exited.connect(_on_body_exited)
	
	# Press E prompt
	prompt_label = Label3D.new()
	prompt_label.text = "Press E to interact"
	prompt_label.position = Vector3(0, 1.5, 0.1)
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.font_size = 48
	prompt_label.outline_size = 8
	prompt_label.visible = false
	add_child(prompt_label)
	
	# UI refs
	status_label = radio_ui.get_node("Control/PanelContainer/VBoxContainer/StatusLabel")
	play_button = radio_ui.get_node("Control/PanelContainer/VBoxContainer/PlayButton")
	code_input = radio_ui.get_node("Control/PanelContainer/VBoxContainer/CodeRow/CodeInput")
	result_label = radio_ui.get_node("Control/PanelContainer/VBoxContainer/ResultLabel")
	
	tone_labels = [
		radio_ui.get_node("Control/PanelContainer/VBoxContainer/ToneDisplay/Tone1"),
		radio_ui.get_node("Control/PanelContainer/VBoxContainer/ToneDisplay/Tone2"),
		radio_ui.get_node("Control/PanelContainer/VBoxContainer/ToneDisplay/Tone3"),
		radio_ui.get_node("Control/PanelContainer/VBoxContainer/ToneDisplay/Tone4"),
	]
	
	play_button.pressed.connect(_on_play_pressed)
	radio_ui.get_node("Control/PanelContainer/VBoxContainer/SubmitButton").pressed.connect(_on_submit_pressed)
	radio_ui.get_node("Control/CloseButton").pressed.connect(_close_ui)
	
	radio_ui.visible = false
	_generate_tones()

func _generate_tones():
	generated_tones.clear()
	for i in range(4):
		var pitch = PITCHES[randi() % 3]
		var duration = DURATIONS[randi() % 2]
		generated_tones.append({"pitch": pitch, "duration": duration})
	
	correct_code = _calculate_code()
	print("=== RADIO TONES ===")
	for i in range(4):
		var t = generated_tones[i]
		print("Tone ", i+1, ": ", t.pitch, " - ", t.duration, " = ", TONE_TABLE[t.pitch + "_" + t.duration])
	print("Correct code: ", correct_code)

func _calculate_code() -> String:
	# step 1 — translate tones to digits
	var digits = []
	var low_count = 0
	var all_short = true
	
	for t in generated_tones:
		var key = t.pitch + "_" + t.duration
		digits.append(TONE_TABLE[key])
		if t.pitch == "Low":
			low_count += 1
		if t.duration != "Short":
			all_short = false
	
	var code = "".join(digits)
	
	# step 2 — apply emergency overrides (first rule only)
	# Critical Meltdown — needs timer, skipping for now
	
	# System Inference — exactly two LOW tones
	if low_count == 2:
		code = "0" + code.substr(1)
		print("Override: System Inference — first digit changed to 0")
	# Power Surge — all SHORT tones
	elif all_short:
		code = code.substr(0, 3) + "9"
		print("Override: Power Surge — last digit changed to 9")
	else:
		print("Override: Standard Override — no changes")
	
	return code

func _on_play_pressed():
	if tones_playing:
		return
	tones_playing = true
	play_button.disabled = true
	status_label.text = "Broadcasting tones..."
	
	# reset tone labels
	for lbl in tone_labels:
		lbl.text = "[ ? ]"
		lbl.add_theme_color_override("font_color", Color.WHITE)
	
	_play_tone_sequence(0)

func _play_tone_sequence(index: int):
	if index >= 4:
		tones_playing = false
		play_button.disabled = false
		status_label.text = "Listen carefully! Enter the code below."
		return
	
	var tone = generated_tones[index]
	var freq = PITCH_FREQ[tone.pitch]
	var dur = DURATION_TIME[tone.duration]
	
	# update label to show current tone
	tone_labels[index].text = tone.pitch.to_upper() + "\n" + tone.duration.to_upper()
	match tone.pitch:
		"High": tone_labels[index].add_theme_color_override("font_color", Color.CYAN)
		"Mid":  tone_labels[index].add_theme_color_override("font_color", Color.YELLOW)
		"Low":  tone_labels[index].add_theme_color_override("font_color", Color.ORANGE)
	
	# generate and play the audio tone
	_play_generated_tone(freq, dur)
	
	# wait for tone + small gap then play next
	await get_tree().create_timer(dur + 0.3).timeout
	_play_tone_sequence(index + 1)

func _play_generated_tone(frequency: float, duration: float):
	var sample_rate = 44100
	var num_samples = int(sample_rate * duration)
	
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = sample_rate
	
	var data = PackedByteArray()
	data.resize(num_samples * 2)
	
	for i in range(num_samples):
		# sine wave with fade in/out to avoid clicks
		var t = float(i) / sample_rate
		var fade = 1.0
		var fade_samples = int(sample_rate * 0.02)
		if i < fade_samples:
			fade = float(i) / fade_samples
		elif i > num_samples - fade_samples:
			fade = float(num_samples - i) / fade_samples
		
		var sample = int(sin(2.0 * PI * frequency * t) * 32767.0 * fade * 0.5)
		sample = clamp(sample, -32768, 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	
	stream.data = data
	tone_player.stream = stream
	tone_player.play()

func _on_submit_pressed():
	var entered = code_input.text.strip_edges()
	if entered.length() != 4:
		result_label.text = "Enter a 4-digit code!"
		result_label.add_theme_color_override("font_color", Color.YELLOW)
		return
	
	if entered == correct_code:
		result_label.text = "✓ OVERRIDE ACCEPTED!"
		result_label.add_theme_color_override("font_color", Color.GREEN)
		puzzle_solved = true
	else:
		result_label.text = "✗ WRONG CODE — Listen again!"
		result_label.add_theme_color_override("font_color", Color.RED)
		code_input.text = ""

func _open_ui():
	if puzzle_solved:
		return
	ui_open = true
	status_label.text = "Press PLAY to broadcast tones"
	result_label.text = ""
	code_input.text = ""
	for lbl in tone_labels:
		lbl.text = "[ ? ]"
		lbl.add_theme_color_override("font_color", Color.WHITE)
	play_button.disabled = false
	radio_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _close_ui():
	ui_open = false
	radio_ui.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = true
		prompt_label.visible = true

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_nearby = false
		prompt_label.visible = false
		if ui_open:
			_close_ui()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("interact"):
		if player_nearby and not ui_open:
			_open_ui()
		elif ui_open:
			_close_ui()
