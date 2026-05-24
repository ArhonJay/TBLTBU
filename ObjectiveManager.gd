extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  ObjectiveManager.gd  –  Autoload singleton
#
#  Register this in Project → Project Settings → Autoload:
#    Name : ObjectiveManager
#    Path : res://ObjectiveManager.gd
# ─────────────────────────────────────────────────────────────────────────────

# ── Targets ───────────────────────────────────────────────────────────────────
const TARGET_CHESTS    : int = 1
const TARGET_SIMON     : int = 1
const TARGET_MUSHROOMS : int = 1

# ── Progress ──────────────────────────────────────────────────────────────────
var chests_done    : int = 0
var simon_done     : int = 0
var mushrooms_done : int = 0
var locker_solved  : bool = false

var _phase : int = 1   # 1 = main objectives, 2 = lab/locker objective

# ── Signals ───────────────────────────────────────────────────────────────────
signal objectives_updated
signal phase_changed(new_phase: int)
signal game_complete


# ── Public API ────────────────────────────────────────────────────────────────

func get_phase() -> int:
	return _phase


func register_chest_solved() -> void:
	if _phase != 1:
		return
	chests_done = min(chests_done + 1, TARGET_CHESTS)
	objectives_updated.emit()
	_check_phase1_complete()


func register_simon_solved() -> void:
	if _phase != 1:
		return
	simon_done = min(simon_done + 1, TARGET_SIMON)
	objectives_updated.emit()
	_check_phase1_complete()


func register_mushroom_eaten() -> void:
	if _phase != 1:
		return
	mushrooms_done = min(mushrooms_done + 1, TARGET_MUSHROOMS)
	objectives_updated.emit()
	_check_phase1_complete()


func register_locker_solved() -> void:
	if _phase != 2:
		return
	locker_solved = true
	objectives_updated.emit()
	game_complete.emit()


# ── Internal ──────────────────────────────────────────────────────────────────

func _check_phase1_complete() -> void:
	if chests_done    >= TARGET_CHESTS    and \
	   simon_done     >= TARGET_SIMON     and \
	   mushrooms_done >= TARGET_MUSHROOMS:
		_phase = 2
		phase_changed.emit(2)
		objectives_updated.emit()
