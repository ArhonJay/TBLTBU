## picklock_ui.gd
## Attach to the PicklockUI CanvasLayer node.
## Draws a spinning-needle lock mini-game inside a SubViewport using _draw().
## No external art assets needed.
##
## The lock has 3 concentric ring layers. One red wedge zone appears at a random
## angle spanning all remaining ring layers. The player must press when the
## spinning needle is inside the red zone.
##
## Hit  : outermost red ring layer is cleared. Zone moves to a new random angle.
##        Speed does NOT change on a hit.
## Miss : all ring layers reset to red, zone re-randomises, speed increases,
##        one pick is consumed.
## Win  : hit 3 times (clear all 3 ring layers) without missing.

extends CanvasLayer

# ── Signals ──────────────────────────────────────────────────────────────────
signal lock_success
signal lock_failed

# ── Tunables ─────────────────────────────────────────────────────────────────
@export var max_attempts   : int   = 3
@export var base_speed_deg : float = 120.0   # deg/sec on first attempt
@export var fail_speed_add : float = 45.0    # extra deg/sec added per miss
@export var speed_increase : float = 200.0    # extra deg/sec added per successful hit
@export var zone_width_deg : float = 45.0    # width of the red wedge in degrees

# ── Ring radii — 3 bands between R_INNER and R_OUTER ─────────────────────────
const R_OUTER : float = 155.0   # outermost edge
const R_BAND2 : float = 130.0   # outer / middle boundary
const R_BAND1 : float = 105.0   # middle / inner boundary
const R_INNER : float = 90.0    # inner edge of ring area (face starts here)
const R_FACE  : float = 62.0    # white keyhole plate
const R_NEEDLE: float = 148.0   # needle tip reaches near outer edge
const R_HUB   : float = 14.0

const CENTER  : Vector2 = Vector2(170, 170)

# ── Colours ───────────────────────────────────────────────────────────────────
const COL_RING_DARK  := Color(0.13, 0.12, 0.10, 1.0)   # unlit ring band
const COL_RING_MID   := Color(0.22, 0.20, 0.16, 1.0)   # cleared band
const COL_RING_LIGHT := Color(0.32, 0.30, 0.24, 1.0)   # ring groove colour
const COL_ZONE_RED   := Color(0.85, 0.15, 0.10, 0.90)  # active red wedge
const COL_ZONE_GREEN := Color(0.15, 0.75, 0.20, 0.85)  # flash on hit
const COL_GROOVE     := Color(0.08, 0.08, 0.07, 1.0)
const COL_NEEDLE     := Color(0.90, 0.82, 0.20, 1.0)
const COL_HUB        := Color(0.55, 0.50, 0.40, 1.0)
const COL_FACE       := Color(0.88, 0.86, 0.80, 1.0)
const COL_KEYHOLE    := Color(0.08, 0.08, 0.08, 1.0)
const COL_TICK       := Color(0.55, 0.50, 0.40, 0.65)
const COL_BORDER     := Color(0.42, 0.38, 0.28, 1.0)

# ── State ─────────────────────────────────────────────────────────────────────
var _needle_angle  : float = 0.0
var _speed         : float = 100.0
var _zone_start    : float = 0.0   # current red wedge start angle (degrees)
var _hits_done     : int   = 0     # 0-2; which ring layers have been cleared
var _attempts_left : int   = 0
var _fails_done    : int   = 0

var _active        : bool  = false
var _accepting     : bool  = true  # false during the brief post-press pause
var _flash_green   : bool  = false # draw zone green briefly after hit
var _flash_timer   : float = 0.0

# UI node refs
var _draw_node    : Node2D
var _result_label : Label
var _attempts_lbl : Label
var _status_label : Label


func _ready() -> void:
	_draw_node    = $Panel/VBox/LockViewport/SubViewport/LockDraw
	_result_label = $Panel/VBox/ResultLabel
	_attempts_lbl = $Panel/VBox/AttemptsLabel
	_status_label = $Panel/VBox/StatusLabel
	$Panel/VBox/CloseButton.pressed.connect(_on_close)
	_draw_node.draw.connect(_on_draw_lock)
	visible = false


func _process(delta: float) -> void:
	if not _active:
		return

	# Advance needle — never stops
	_needle_angle = fmod(_needle_angle + _speed * delta, 360.0)
	if _needle_angle < 0.0:
		_needle_angle += 360.0

	# Tick flash timer
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_green  = false
			_flash_timer  = 0.0
			_result_label.text = ""

	_draw_node.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		if _accepting:
			_on_player_press()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()


# ── Public API ────────────────────────────────────────────────────────────────
func open() -> void:
	_attempts_left = max_attempts
	_fails_done    = 0
	_hits_done     = 0
	_active        = true
	_accepting     = true
	visible        = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_randomise_zone()
	_apply_speed()
	_refresh_ui()


func close() -> void:
	_active = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── Internal helpers ──────────────────────────────────────────────────────────

func _randomise_zone() -> void:
	_zone_start = randf_range(0.0, 360.0)

func _apply_speed() -> void:
	# Base speed + bonus per miss + bonus per hit in current streak.
	# Direction alternates each miss so the needle doesn't always spin the same way.
	var raw : float = base_speed_deg \
		+ fail_speed_add * float(_fails_done) \
		+ speed_increase * float(_hits_done)
	var dir : float = 1.0 if _fails_done % 2 == 0 else -1.0
	_speed = raw * dir

func _refresh_ui() -> void:
	_attempts_lbl.text = "Picks remaining: %d" % _attempts_left
	_status_label.text = "Press  SPACE  or  E  to stop"

func _needle_in_zone() -> bool:
	var a   : float = _needle_angle   # already 0-360
	var end : float = fmod(_zone_start + zone_width_deg, 360.0)
	if end > _zone_start:
		return a >= _zone_start and a <= end
	else:
		return a >= _zone_start or a <= end


func _on_player_press() -> void:
	_accepting = false   # block input during flash

	if _needle_in_zone():
		# ── HIT ──────────────────────────────────────────────────────────────
		_hits_done    += 1
		_apply_speed()   # needle gets faster immediately after each hit
		_flash_green   = true
		_flash_timer   = 0.45

		if _hits_done >= 3:
			# All 3 rings cleared — WIN
			_result_label.text = "✓  UNLOCKED!"
			_result_label.add_theme_color_override("font_color", Color.GREEN)
			_status_label.text = ""
			_flash_timer = 1.3
			_active = false
			await get_tree().create_timer(1.3).timeout
			close()
			emit_signal("lock_success")
			return
		else:
			_result_label.text = "✓  Hit!  %d / 3" % _hits_done
			_result_label.add_theme_color_override("font_color", Color.GREEN)
			# Move zone to new random position; speed unchanged
			await get_tree().create_timer(0.35).timeout
			if not _active:
				return
			_randomise_zone()
			_flash_green  = false
			_result_label.text = ""
			_accepting = true
	else:
		# ── MISS ─────────────────────────────────────────────────────────────
		_hits_done     = 0   # reset all ring layers
		_fails_done   += 1
		_attempts_left -= 1
		_flash_green   = false
		_flash_timer   = 0.6

		if _attempts_left <= 0:
			_result_label.text = "✗  Out of picks!"
			_result_label.add_theme_color_override("font_color", Color.RED)
			_status_label.text = ""
			_flash_timer = 1.5
			_active = false
			await get_tree().create_timer(1.5).timeout
			close()
			emit_signal("lock_failed")
			return
		else:
			_result_label.text = "✗  Missed!  Reset…"
			_result_label.add_theme_color_override("font_color", Color.ORANGE_RED)
			_attempts_lbl.text = "Picks remaining: %d" % _attempts_left
			await get_tree().create_timer(0.6).timeout
			if not _active:
				return
			# Re-randomise zone and increase speed
			_randomise_zone()
			_apply_speed()
			_result_label.text = ""
			_accepting = true

	_draw_node.queue_redraw()


func _on_close() -> void:
	close()
	emit_signal("lock_failed")


# ── Drawing ───────────────────────────────────────────────────────────────────
# Ring layers (outermost = index 0, innermost = index 2).
# _hits_done tells us how many have been cleared from the outside in.
# Cleared rings are drawn dark. Active (red) rings are drawn with the zone wedge.

func _on_draw_lock() -> void:
	var cv : CanvasItem = _draw_node

	# ── Full disc background ──────────────────────────────────────────────────
	cv.draw_circle(CENTER, R_OUTER, COL_RING_DARK)

	# ── Draw the 3 ring bands (outer→inner = index 0,1,2) ────────────────────
	# Band radii pairs: [outer_r, inner_r]
	var bands : Array = [
		[R_OUTER, R_BAND2],
		[R_BAND2, R_BAND1],
		[R_BAND1, R_INNER]
	]

	var zone_col : Color = COL_ZONE_GREEN if _flash_green else COL_ZONE_RED

	for b in range(3):
		var r_out : float = bands[b][0]
		var r_in  : float = bands[b][1]
		var cleared : bool = b < _hits_done   # this layer has been hit already

		if cleared:
			# Draw the cleared band as a dark annulus
			_draw_annulus(cv, r_out, r_in, COL_RING_MID)
		else:
			# Draw the full band background
			_draw_annulus(cv, r_out, r_in, COL_RING_DARK)
			# Draw the red (or green flash) zone wedge within this band
			_draw_wedge_band(cv, r_out, r_in, _zone_start, zone_width_deg, zone_col)

		# Groove ring line at the inner edge of this band
		cv.draw_arc(CENTER, r_in, 0, TAU, 90, COL_GROOVE, 2.0)

	# Outer border circle
	cv.draw_arc(CENTER, R_OUTER, 0, TAU, 120, COL_BORDER, 3.0)

	# Groove ring at R_OUTER inner edge
	cv.draw_arc(CENTER, R_BAND2, 0, TAU, 90, COL_BORDER.darkened(0.3), 1.5)
	cv.draw_arc(CENTER, R_BAND1, 0, TAU, 90, COL_BORDER.darkened(0.3), 1.5)

	# Tick marks on the outermost band
	for t in range(36):
		var ang_rad : float   = deg_to_rad(t * 10.0)
		var dir     : Vector2 = Vector2(sin(ang_rad), -cos(ang_rad))
		var r0      : float   = R_BAND2 + 4.0
		var r1      : float   = R_OUTER - (6.0 if t % 3 == 0 else 2.0)
		cv.draw_line(CENTER + dir * r0, CENTER + dir * r1, COL_TICK, 1.2)

	# ── Inner face (white plate) ──────────────────────────────────────────────
	cv.draw_circle(CENTER, R_FACE, COL_FACE)

	# Keyhole
	var kh_r : float = 9.0
	var kh_h : float = 16.0
	var kh_w : float = 7.0
	cv.draw_circle(CENTER + Vector2(0.0, -3.0), kh_r, COL_KEYHOLE)
	cv.draw_rect(Rect2(CENTER + Vector2(-kh_w * 0.5, 5.0), Vector2(kh_w, kh_h)), COL_KEYHOLE)

	# ── Needle ────────────────────────────────────────────────────────────────
	var n_rad  : float   = deg_to_rad(_needle_angle - 90.0)
	var n_dir  : Vector2 = Vector2(sin(n_rad), -cos(n_rad))
	var n_tip  : Vector2 = CENTER + n_dir * R_NEEDLE
	var n_tail : Vector2 = CENTER - n_dir * 18.0
	# Shadow
	cv.draw_line(n_tail + Vector2(1, 2), n_tip + Vector2(1, 2), Color(0, 0, 0, 0.35), 5.0)
	# Needle body
	cv.draw_line(n_tail, n_tip, COL_NEEDLE, 3.5)
	# Tip dot
	cv.draw_circle(n_tip, 4.0, COL_NEEDLE.lightened(0.25))

	# ── Hub ───────────────────────────────────────────────────────────────────
	cv.draw_circle(CENTER, R_HUB, COL_HUB)
	cv.draw_circle(CENTER, R_HUB * 0.45, COL_HUB.darkened(0.45))


## Draw a filled annulus (ring band) as a polygon approximation.
func _draw_annulus(cv: CanvasItem, r_out: float, r_in: float, col: Color) -> void:
	var steps : int = 90
	var pts   : PackedVector2Array = []
	# Outer arc clockwise
	for i in range(steps + 1):
		var a : float = TAU * float(i) / float(steps)
		pts.append(CENTER + Vector2(cos(a), sin(a)) * r_out)
	# Inner arc counter-clockwise
	for i in range(steps + 1):
		var a : float = TAU * float(steps - i) / float(steps)
		pts.append(CENTER + Vector2(cos(a), sin(a)) * r_in)
	cv.draw_colored_polygon(pts, col)


## Draw a wedge slice of a ring band (zone highlight).
func _draw_wedge_band(cv: CanvasItem, r_out: float, r_in: float,
		zone_start_deg: float, width_deg: float, col: Color) -> void:
	var steps     : int   = max(12, int(width_deg / 2))
	var zs_rad    : float = deg_to_rad(zone_start_deg - 90.0)
	var ze_rad    : float = zs_rad + deg_to_rad(width_deg)
	var pts       : PackedVector2Array = []
	# Outer arc
	for s in range(steps + 1):
		var a : float = zs_rad + (ze_rad - zs_rad) * float(s) / float(steps)
		pts.append(CENTER + Vector2(sin(a), -cos(a)) * r_out)
	# Inner arc reversed
	for s in range(steps + 1):
		var a : float = ze_rad - (ze_rad - zs_rad) * float(s) / float(steps)
		pts.append(CENTER + Vector2(sin(a), -cos(a)) * r_in)
	cv.draw_colored_polygon(pts, col)
