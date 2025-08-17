# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Car brain for hooking user input to the car.
class_name BotBrain extends ACarBrain

const RECOVERY_DURATION_MS: float = 2_000
var _lastRecoveryWantedTimestamp: float = -RECOVERY_DURATION_MS

func tick(globalPos: Vector3, debugPos: Vector3, globalBasis: Basis, frontColliding: bool) -> void:
	if (path == null):
		return
	
	var speedSquared: float = populatedLinVel.length_squared()
	
	if (frontColliding && speedSquared < 1):
		_lastRecoveryWantedTimestamp = Time.get_ticks_msec()
	
	var q: RacePath.QueryInfo = path.query_info(globalPos)
	lastQueryInfo = q
	
	# The path needs to be extended beyond start and stop limits for the bot
	# to behave correctly.
	if (q.prev != null && q.next != null):
		var globalPosXZ = _xz(globalPos)
		var ratioPrevNext: float = q.closestOffset - q.prevOffset / max(q.nextOffset - q.prevOffset, 0.01)
		var trackWidthSquared: float = lerp(q.prev.rangeRadius, q.next.rangeRadius, ratioPrevNext)
		trackWidthSquared *= trackWidthSquared
		var distanceSquaredFromCenter: float = globalPos.distance_squared_to(q.closestPoint) 
		# TODO account for car width
		var targetOffsetAhead: int = min(10, int(speedSquared) << 3) # divide by 8
		var targetPosAhead: Vector3 = _xz(path.curve.sample_baked(q.closestOffset + targetOffsetAhead))
		# try to take into account the car's distance from the center by offseting according to the closest
		# offset (different from ahead offest). The goal is to limit the left to right yoyo effect.
		# Side effects on correctly handling turns should be relatively small.
		var trackSide: float = sign(q.forwardBasis.x.dot(globalPosXZ - _xz(q.closestPoint)))
		targetPosAhead += _xz(q.forwardBasis.x) * trackSide * min(distanceSquaredFromCenter, trackWidthSquared * 0.5) * 0.1
		var wantedDirNormalized: Vector3 = _xz(targetPosAhead - globalPos).normalized()
		var currentDirNormalized: Vector3 = _xz(populatedLinVel).normalized()
		## angle between -PI and PI.
		var wantedVSCurrentDiff: float = wantedDirNormalized.signed_angle_to(currentDirNormalized, Vector3.UP)
		## We go forward on X, so to have 0 if right direction (and a signed diff otherwise),
		## we need an angle of 90°. To do so we use the Z axis of the basis.
		#var wantedVSCurrentDiff: float = wantedDirNormalized.dot(globalBasis.z)
		## if above 90° in the wrong direction, it goes back to 0, messing up directions.
		## We try to mitigate that by making it continue to +-2 toward 180°.
		#var xAxisWantedVSCurrentDiff: float = wantedDirNormalized.dot(globalBasis.x)
		#if (xAxisWantedVSCurrentDiff < 0):
			#wantedVSCurrentDiff += xAxisWantedVSCurrentDiff * -1
		## 0 if aligned, growing the more it is not. Between 0 and PI
		var notAlignedToPath: float = abs(_xz(q.forwardBasis.z).signed_angle_to(_xz(globalBasis.z), Vector3.UP))
		var preparedLeftRight: float = wantedVSCurrentDiff * 2
		if (distanceSquaredFromCenter < trackWidthSquared):
			preparedLeftRight *= notAlignedToPath
		
		_leftRight = clampf(preparedLeftRight, -1, 1)
		_driftActive = abs(_leftRight) > 0.9
		
		DebugDraw2D.set_text("_forwardBackward", _forwardBackward)
		DebugDraw2D.set_text("_leftRight", _leftRight)
		DebugDraw2D.set_text("trackWidthSquared", trackWidthSquared)
		DebugDraw2D.set_text("distanceSquaredFromCenter", distanceSquaredFromCenter)
		DebugDraw2D.set_text("targetOffsetAhead", targetOffsetAhead)
		DebugDraw2D.set_text("distanceSquaredFromCenter", distanceSquaredFromCenter)
		DebugDraw2D.set_text("trackSide", trackSide)
		DebugDraw2D.set_text("wantedVSCurrentDiff", wantedVSCurrentDiff)
		
		
		DebugDraw3D.draw_arrow(debugPos, debugPos + lastQueryInfo.forwardBasis.z, Color(0.8,0.8,1), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + lastQueryInfo.forwardBasis.x, Color(0.8,0.8,1), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + (globalPos - lastQueryInfo.closestPoint), Color(1,1,0), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + wantedDirNormalized, Color(1,0.85,0.85), 0.1)

	else:
		_leftRight = 0
	
	if (_recovering()):
		_forwardBackward = -1
		_leftRight *= -1
	else:
		_forwardBackward = 1
		
func _recovering() -> bool:
	var now: float = Time.get_ticks_msec()
	return now - _lastRecoveryWantedTimestamp < RECOVERY_DURATION_MS

func _xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
