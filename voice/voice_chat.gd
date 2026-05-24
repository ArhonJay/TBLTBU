extends Node3D

var input_player: AudioStreamPlayer
var output_player: AudioStreamPlayer

var capture_effect: AudioEffectCapture
var playback: AudioStreamGeneratorPlayback
var record_bus_idx: int

func _ready():
	await get_tree().process_frame
	
	if is_multiplayer_authority():
		_setup_microphone()
	else:
		_setup_speaker()

func _setup_microphone():
	input_player = AudioStreamPlayer.new()
	add_child(input_player)
	
	input_player.stream = AudioStreamMicrophone.new()
	input_player.bus = "Record" 
	input_player.play()

	record_bus_idx = AudioServer.get_bus_index("Record")
	capture_effect = AudioServer.get_bus_effect(record_bus_idx, 0)

func _setup_speaker():
	output_player = AudioStreamPlayer.new()
	add_child(output_player)
	
	var generator = AudioStreamGenerator.new()
	# FIX 1: Match your PC's exact hardware sample rate!
	generator.mix_rate = AudioServer.get_mix_rate() 
	output_player.stream = generator
	
	# FIX 2: Boost the volume so it is impossible to miss
	output_player.volume_db = 20.0
	output_player.play()
	
	playback = output_player.get_stream_playback()

func _process(_delta):
	if is_multiplayer_authority() and capture_effect != null:
		var frames_available = capture_effect.get_frames_available()
		
		if frames_available > 1024: 
			var buffer = capture_effect.get_buffer(frames_available)
			_receive_audio.rpc(buffer)

@rpc("any_peer", "unreliable", "call_remote")
func _receive_audio(buffer: PackedVector2Array):
	
	if playback != null:
		if playback.can_push_buffer(buffer.size()):
			playback.push_buffer(buffer)
		else:
			# DEBUG PRINT 2: This tells us the audio engine is jammed!
			print("WARNING: Speaker buffer is full! Dropping audio.")
