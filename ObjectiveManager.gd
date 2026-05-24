extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  ObjectiveManager  (AutoLoad singleton)
#
#  Add this file as an AutoLoad in:
#    Project → Project Settings → AutoLoad
#    Name : ObjectiveManager
#    Path : res://ObjectiveManager.gd
#
#  How to hook up the existing puzzle scripts
#  ─────────────────────────────────────────
#  chest.gd          → call  ObjectiveManager.complete_chest()
#                       inside  _on_lock_success()   (already calls _on_chest_unlocked)
#
#  simon_says.gd     → call  ObjectiveManager.complete_simon()
#                       where  puzzle_solved = true   (the "MODULE DISARMED" branch)
#
#  mushroom_patch.gd → call  ObjectiveManager.complete_mushroom()
#                       inside  _on_eat_pressed()  when action == "EAT"  (correct eat)
#
#  locker_interaction.gd → call  ObjectiveManager.complete_locker()
#                           inside  _on_locker_unlocked()
# ─────────────────────────────────────────────────────────────────────────────

signal objectives_updated          # emitted whenever any counter changes
signal phase_changed(new_phase)    # emitted when switching between phase 1 and phase 2
signal game_complete               # emitted when the locker is finally solved

# ── Targets ───────────────────────────────────────────────────────────────────
const TARGET_CHESTS    := 5
const TARGET_SIMON     := 5
const TARGET_MUSHROOMS := 10

# ── Phase 1 progress ──────────────────────────────────────────────────────────
var chests_done    := 0
var simon_done     := 0
var mushrooms_done := 0

# ── Phase tracking ────────────────────────────────────────────────────────────
# phase 1 = three main objectives active
# phase 2 = laboratory / locker objective active
var current_phase  := 1

var locker_solved  := false


# ── Public API ────────────────────────────────────────────────────────────────

func complete_chest() -> void:
	if current_phase != 1:
		return
	chests_done = min(chests_done + 1, TARGET_CHESTS)
	emit_signal("objectives_updated")
	_check_phase_transition()


func complete_simon() -> void:
	if current_phase != 1:
		return
	simon_done = min(simon_done + 1, TARGET_SIMON)
	emit_signal("objectives_updated")
	_check_phase_transition()


func complete_mushroom() -> void:
	if current_phase != 1:
		return
	mushrooms_done = min(mushrooms_done + 1, TARGET_MUSHROOMS)
	emit_signal("objectives_updated")
	_check_phase_transition()


func complete_locker() -> void:
	if current_phase != 2 or locker_solved:
		return
	locker_solved = true
	emit_signal("objectives_updated")
	emit_signal("game_complete")


# ── Internal helpers ──────────────────────────────────────────────────────────

func _check_phase_transition() -> void:
	if chests_done    >= TARGET_CHESTS   and \
	   simon_done     >= TARGET_SIMON    and \
	   mushrooms_done >= TARGET_MUSHROOMS:
		current_phase = 2
		emit_signal("phase_changed", 2)
		emit_signal("objectives_updated")


func is_phase1_complete() -> bool:
	return current_phase == 2


func get_phase() -> int:
	return current_phase
