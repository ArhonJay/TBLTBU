extends Control

@onready var audio_name_label: Label = $HBoxContainer/AudioNameLabel as Label 
@onready var audio_num_label: Label = $HBoxContainer/AudioNumLabel as Label
@onready var h_slider: HSlider = $HBoxContainer/HSlider as HSlider

@export_enum("Master", "Music", "SFX") var bus_name : String

var bus_index : int = 0

func _ready() -> void:
	h_slider.value_changed.connect(_on_value_changed)
	_get_bus_name_by_index()
	_set_name_label_text()
	_set_slider_value()
	
func _set_name_label_text() -> void:
	audio_name_label.text = str(bus_name) + " Volume"

func _set_audio_num_label_text() -> void:
	audio_num_label.text = "%.1f%%" % h_slider.value

func _get_bus_name_by_index() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)
	
func _set_slider_value() -> void:
	h_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100
	_set_audio_num_label_text()
	
func _on_value_changed(value : float) -> void:
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
	_set_audio_num_label_text()
