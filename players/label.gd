extends Label

func _ready():
	# In multiplayer, every player gets a Player node. 
	# We ONLY want the timer to run and be visible for the player actually playing on this machine.
	# get_multiplayer_authority() checks who "owns" this specific player node.
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		
		# --- THIS IS WHERE WE CONNECT THE SIGNALS ---
		# Syntax: AutoloadName.signal_name.connect(my_local_function)
		
		NetworkManager.time_updated.connect(_on_time_updated)
		NetworkManager.match_ended_time_out.connect(_on_match_timeout)
		
	else:
		# If this player node belongs to someone else over the network, 
		# hide their CanvasLayer so we don't see two timers overlapping on our screen.
		get_parent().hide() 


# This function automatically runs whenever NetworkManager emits 'time_updated'
func _on_time_updated(time_left: int):
	# Calculate minutes and seconds
	var minutes = time_left / 60
	var seconds = time_left % 60
	
	# Update the label's text. %02d forces it to always show two digits (e.g., 05 instead of 5)
	text = "%02d:%02d" % [minutes, seconds]
	
	# Optional: Turn text red if 30 seconds or less remain
	if time_left <= 30:
		add_theme_color_override("font_color", Color(1, 0, 0))
	else:
		remove_theme_color_override("font_color")


# This function automatically runs whenever NetworkManager emits 'match_ended_time_out'
func _on_match_timeout():
	text = "00:00"
	add_theme_color_override("font_color", Color(1, 0, 0))

	var explorer = get_tree().get_first_node_in_group("explorer")
	if explorer and explorer.has_method("_on_timeout_death"):
		explorer._on_timeout_death()
