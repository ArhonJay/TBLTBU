extends CanvasLayer

# ─────────────────────────────────────────────────────────────────────────────
#  GameEndSequence.gd
#
#  One instance lives on the scene root for EACH peer.
#  When ObjectiveManager emits game_complete, start_sequence.rpc() fires on
#  ALL peers simultaneously. Stats are read from ObjectiveManager on the
#  calling peer (explorer's machine, where they are correct) and broadcast
#  to all peers so both MissionReports show identical data.
#
#  Flow:
#    1. Screen fades to black
#    2. Video plays
#    3. Video ends → MissionReport.setup(stats) → fade in
# ─────────────────────────────────────────────────────────────────────────────

const MISSION_REPORT_SCENE := preload("res://puzzles/scenes/MissionReport.tscn")

const VIDEO_PATH    := "res://video/ending_scene.ogv"
const FADE_DURATION : float = 1.8

var _black : ColorRect
var _video : VideoStreamPlayer
var _sequence_started := false

# Stats snapshot sent from the authoritative peer.
var _stats : Dictionary = {}


func _ready() -> void:
	layer = 20

	_black            = ColorRect.new()
	_black.color      = Color(0, 0, 0, 1)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	_black.visible    = false
	add_child(_black)

	_video         = VideoStreamPlayer.new()
	_video.expand  = true
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.visible = false
	_video.finished.connect(_on_video_finished)
	add_child(_video)

	ObjectiveManager.game_complete.connect(_on_game_complete)


# ── Whichever peer receives game_complete reads the real stats and broadcasts. ─
func _on_game_complete() -> void:
	if _sequence_started:
		return
	# Snapshot stats from ObjectiveManager — only correct on the explorer's peer.
	start_sequence.rpc(
		ObjectiveManager.chests_done,
		ObjectiveManager.simon_done,
		ObjectiveManager.mushrooms_done,
		ObjectiveManager.locker_solved,
		ObjectiveManager.get_elapsed_formatted(),
		ObjectiveManager.TARGET_CHESTS,
		ObjectiveManager.TARGET_SIMON,
		ObjectiveManager.TARGET_MUSHROOMS
	)


# ── Runs on ALL peers via RPC (call_local = also on caller). ─────────────────
@rpc("call_local", "any_peer", "reliable")
func start_sequence(
		chests_done: int, simon_done: int, mushrooms_done: int,
		locker_solved: bool, elapsed: String,
		target_chests: int, target_simon: int, target_mushrooms: int) -> void:
	if _sequence_started:
		return
	_sequence_started = true
	_stats = {
		"chests_done":     chests_done,
		"simon_done":      simon_done,
		"mushrooms_done":  mushrooms_done,
		"locker_solved":   locker_solved,
		"elapsed":         elapsed,
		"TARGET_CHESTS":   target_chests,
		"TARGET_SIMON":    target_simon,
		"TARGET_MUSHROOMS":target_mushrooms,
	}
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_fade_to_black()


# ── Step 1 ────────────────────────────────────────────────────────────────────
func _fade_to_black() -> void:
	_black.visible    = true
	_black.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(_play_video)


# ── Step 2 ────────────────────────────────────────────────────────────────────
func _play_video() -> void:
	if not ResourceLoader.exists(VIDEO_PATH):
		push_warning("GameEndSequence: video not found at '%s'. Skipping to report." % VIDEO_PATH)
		_on_video_finished()
		return

	var stream = load(VIDEO_PATH)
	if stream == null:
		push_warning("GameEndSequence: load() returned null for '%s'. Skipping to report." % VIDEO_PATH)
		_on_video_finished()
		return

	_video.stream  = stream
	_video.visible = true
	_video.play()


# ── Step 3 ────────────────────────────────────────────────────────────────────
func _on_video_finished() -> void:
	_video.stop()
	_video.visible    = false
	_black.modulate.a = 1.0

	# Spawn the report on the scene root if not already there.
	var report : Node = get_tree().current_scene.get_node_or_null("MissionReport")
	if report == null:
		report = MISSION_REPORT_SCENE.instantiate()
		report.name = "MissionReport"
		get_tree().current_scene.add_child(report)

	# Pass the synced stats before _build_ui runs.
	report.setup(_stats)

	# One frame for the report's _ready() to finish building the UI.
	await get_tree().process_frame

	# Fade out backdrop to reveal the report.
	var cover : ColorRect = report.get_cover()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_black, "modulate:a", 0.0, 0.8)
	tween.tween_property(cover, "color:a",     0.0, 0.8)
	tween.chain().tween_callback(func(): _black.visible = false)
