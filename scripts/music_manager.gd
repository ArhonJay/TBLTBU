extends Node

var player: AudioStreamPlayer

func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)

func play_music(stream: AudioStream):
	if player.stream != stream:
		player.stream = stream
		player.play()
