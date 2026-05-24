extends Node2D

var slides = [
	preload("res://assets/c_assets/tutorial/1.png"),
	preload("res://assets/c_assets/tutorial/2.png"),
	preload("res://assets/c_assets/tutorial/3.png"),
	preload("res://assets/c_assets/tutorial/4.png"),
	preload("res://assets/c_assets/tutorial/5.png"),
	preload("res://assets/c_assets/tutorial/6.png"),
]

var current_slide = 0

@onready var slide_image: TextureRect = $SlideImage
@onready var next_btn: TextureButton = $ButtonManager/NextButton
@onready var prev_btn: TextureButton = $ButtonManager/PrevButton

func _ready():
	update_slide()
	next_btn.pressed.connect(_on_next)
	prev_btn.pressed.connect(_on_prev)

func update_slide():
	slide_image.texture = slides[current_slide]
	prev_btn.disabled = current_slide == 0
	next_btn.disabled = current_slide == slides.size() - 1

func _on_next():
	if current_slide < slides.size() - 1:
		current_slide += 1
		update_slide()

func _on_prev():
	if current_slide > 0:
		current_slide -= 1
		update_slide()
