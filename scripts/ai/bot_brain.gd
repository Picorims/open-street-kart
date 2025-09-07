# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Car brain for hooking user input to the car.
class_name BotBrain extends ACarBrain

const RECOVERY_DURATION_MS: float = 2_000
var _last_recovery_wanted_timestamp: float = - RECOVERY_DURATION_MS

func tick(global_pos: Vector3, debug_pos: Vector3, global_basis: Basis, local_basis: Basis, front_colliding: bool, on_ground: bool) -> void:
	super (global_pos, debug_pos, global_basis, local_basis, front_colliding, on_ground)
	if (path == null):
		return

	_forward_backward = 1
	var speed: float = populated_lin_vel.length()
	
	# HACK second part of the if only there while there is the weird drive on wall bug.
	if ((front_colliding and speed < 1) or (speed < 0.1 and local_basis.y.dot(Vector3.UP) < 0.2)):
		_last_recovery_wanted_timestamp = Time.get_ticks_msec()
	
	var q: RacePath.QueryInfo = last_query_info
	
	var global_pos_xz = _xz(global_pos)
	# The path needs to be extended beyond start and stop limits for the bot
	# to behave correctly.
	var track_width: float = 0
	var prev_null = q.prev == null
	var next_null = q.next == null
	var ratio_prev_next: float = 0
	if (not prev_null and not next_null):
		ratio_prev_next = (q.closest_offset - q.prev_offset) / max(q.next_offset - q.prev_offset, 0.01)
		track_width = lerp(q.prev.range_radius, q.next.range_radius, ratio_prev_next)
	elif (not next_null):
		track_width = q.next.range_radius
	elif (not prev_null):
		track_width = q.prev.range_radius
	else:
		track_width = 1
	# without XZ, issues would be exacerbated with height difference, which is not important to know.
	# So we do everything on a 2D plane at 0.
	var distance_from_center: float = _xz(global_pos).distance_to(_xz(q.closest_point))
	# TODO account for car width
	var target_offset_ahead: int = max(12, 0.6 * speed + 8)
	var target_pos_ahead: Vector3 = _xz(path.curve.sample_baked(q.closest_offset + target_offset_ahead))
	# try to take into account the car's distance from the center by offseting according to the closest
	# offset (different from ahead offest). The goal is to limit the left to right yoyo effect.
	# Side effects on correctly handling turns should be relatively small.
	var track_side: float = sign(q.forward_basis.x.dot(global_pos_xz - _xz(q.closest_point)))
	var adjusted_offset: float = (track_side * min(distance_from_center, track_width * 0.15))
	target_pos_ahead += _xz(q.forward_basis.x).normalized() * adjusted_offset
	var wanted_dir_normalized: Vector3 = _xz(target_pos_ahead - global_pos).normalized()
	var current_dir_normalized: Vector3 = _xz(populated_lin_vel).normalized()
	## angle between -PI and PI.
	var wanted_vs_current_diff: float = wanted_dir_normalized.signed_angle_to(current_dir_normalized, Vector3.UP)
	## We go forward on X, so to have 0 if right direction (and a signed diff otherwise),
	## we need an angle of 90°. To do so we use the Z axis of the basis.
	#var wantedVSCurrentDiff: float = wantedDirNormalized.dot(globalBasis.z)
	## if above 90° in the wrong direction, it goes back to 0, messing up directions.
	## We try to mitigate that by making it continue to +-2 toward 180°.
	#var xAxisWantedVSCurrentDiff: float = wantedDirNormalized.dot(globalBasis.x)
	#if (xAxisWantedVSCurrentDiff < 0):
		#wantedVSCurrentDiff += xAxisWantedVSCurrentDiff * -1
	## 0 if aligned, growing the more it is not. Between 0 and PI
	var not_aligned_to_path: float = abs(_xz(q.forward_basis.z).signed_angle_to(_xz(global_basis.z), Vector3.UP))
	var prepared_left_right: float = wanted_vs_current_diff * 4 # much more agressive decision to turn
	if (distance_from_center < track_width):
		prepared_left_right *= not_aligned_to_path
	
	var prev_left_right = _left_right
	_left_right = clampf(prepared_left_right, -1, 1)
	
	# HACK temporarily disable turning in air due to addociated physics bug
	if (not on_ground):
		_left_right = 0
	
	# sign check avoid bot being stuck going forward while wanting to turn.
	# The bot is not able to take advantage of slow turn mechanism of drift.
	_drift_active = abs(_left_right) > 0.9 and sign(prev_left_right) == sign(_left_right)
	
	# === FOR DEBUGGING VARIABLES vvvv ===
	#DebugDraw2D.set_text("_forwardBackward", _forwardBackward)
	#DebugDraw2D.set_text("_leftRight", _leftRight)
	#DebugDraw2D.set_text("trackWidth", trackWidth)
	#DebugDraw2D.set_text("distanceFromCenter", distanceFromCenter)
	#DebugDraw2D.set_text("targetOffsetAhead", targetOffsetAhead)
	#DebugDraw2D.set_text("trackSide", trackSide)
	#DebugDraw2D.set_text("wantedVSCurrentDiff", wantedVSCurrentDiff)
	#DebugDraw2D.set_text("ratioPrevNext", ratioPrevNext)
	#DebugDraw2D.set_text("adjustedOffset", adjustedOffset)
	# === FOR DEBUGGING VARIABLES ^^^^ ===
	
	if (show_debug_arrows):
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + last_query_info.forward_basis.z, Color(0.8, 0.8, 1), 0.1)
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + last_query_info.forward_basis.x, Color(0.8, 0.8, 1), 0.1)
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + (global_pos - last_query_info.closest_point), Color(1, 1, 0), 0.1)
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + wanted_dir_normalized, Color(1, 0.85, 0.85), 0.1)
		DebugDraw3D.draw_line(target_pos_ahead + Vector3(0, -100, 0), target_pos_ahead + Vector3(0, 100, 0), Color(0, 0, 0))
	
	if (_recovering()):
		_forward_backward = -1
		_left_right *= -1
		
func _recovering() -> bool:
	var now: float = Time.get_ticks_msec()
	return now - _last_recovery_wanted_timestamp < RECOVERY_DURATION_MS

func _xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
