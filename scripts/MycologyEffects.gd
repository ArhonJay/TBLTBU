# MycologyEffects.gd
# Attach this to any persistent node (e.g. your GameManager, or the Player itself).
# Connect MycologyUI.puzzle_resolved signal to _on_puzzle_resolved().
#
# This is where you hook puzzle outcomes into your actual game systems.
extends Node

# ── Connect this in _ready or via the editor signal dock ────────────────────
# $MycologyUI.puzzle_resolved.connect(_on_puzzle_resolved)

func _on_puzzle_resolved(
		mushroom_id: String,
		player_action: String,
		toxic: bool,
		effect: String
) -> void:
	print("[MycologyEffects] id=%s action=%s toxic=%s effect=%s"
		% [mushroom_id, player_action, str(toxic), effect])

	# Only apply effects if player actually ate the mushroom
	if player_action != "EAT":
		return

	match mushroom_id:
		"glowing_blue":
			if not toxic:
				# Lunar Cap — restore health
				_heal_player(30)
			else:
				# Static Spore — blindness
				_apply_status("blind", 10.0)

		"red_spotted":
			if not toxic:
				# Blood Truffle — speed boost
				_apply_status("speed_boost", 15.0)
			else:
				# Magma Cap — poison
				_apply_status("poison", 20.0)

		"pale_fleshy":
			if not toxic:
				# Sulfur Sponge — cure all negatives
				_clear_negative_statuses()
			else:
				# Corpse Trap — paralysis
				_apply_status("paralysis", 8.0)

# ── Stubs — replace with your actual player/game API ────────────────────────

func _heal_player(amount: int) -> void:
	# Example: get_tree().get_first_node_in_group("player").heal(amount)
	print("HEAL player by %d" % amount)

func _apply_status(status: String, duration: float) -> void:
	# Example: PlayerStatus.add(status, duration)
	print("APPLY STATUS: %s for %.1f seconds" % [status, duration])

func _clear_negative_statuses() -> void:
	# Example: PlayerStatus.clear_negatives()
	print("CLEAR all negative status effects")
