extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  ObjectiveManager.gd  –  Autoload singleton
#
#  Register this in Project → Project Settings → Autoload:
#    Name : ObjectiveManager
#    Path : res://ObjectiveManager.gd
# ─────────────────────────────────────────────────────────────────────────────

# ── Targets ───────────────────────────────────────────────────────────────────
const TARGET_CHESTS    : int = 5
const TARGET_SIMON     : int = 3
const TARGET_MUSHROOMS : int = 10

# ── Progress ──────────────────────────────────────────────────────────────────
var chests_done    : int = 0
var simon_done     : int = 0
var mushrooms_done : int = 0
var locker_solved  : bool = false

var _phase      : int   = 1
var _timer_running : bool  = false
var elapsed_time   : float = 0.0   # seconds – read by MissionReport

# ── Signals ───────────────────────────────────────────────────────────────────
signal objectives_updated
signal phase_changed(new_phase: int)
signal game_complete


# ── Public API ────────────────────────────────────────────────────────────────

func get_phase() -> int:
	return _phase


func start_timer() -> void:
	elapsed_time   = 0.0
	_timer_running = true


func stop_timer() -> void:
	_timer_running = false


func get_elapsed_formatted() -> String:
	var t   := int(elapsed_time)
	var hrs := t / 3600
	var mn  := (t % 3600) / 60
	var sec := t % 60
	if hrs > 0:
		return "%d:%02d:%02d" % [hrs, mn, sec]
	return "%02d:%02d" % [mn, sec]


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
	stop_timer()
	locker_solved = true
	objectives_updated.emit()
	game_complete.emit()


# ── Internal ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _timer_running:
		elapsed_time += delta


func _check_phase1_complete() -> void:
	if chests_done    >= TARGET_CHESTS    and \
	   simon_done     >= TARGET_SIMON     and \
	   mushrooms_done >= TARGET_MUSHROOMS:
		_phase = 2
		phase_changed.emit(2)
		objectives_updated.emit()
