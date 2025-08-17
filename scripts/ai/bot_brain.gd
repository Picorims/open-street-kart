# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Car brain for hooking user input to the car.
class_name BotBrain extends ACarBrain

func tick(globalPos: Vector3, debugPos: Vector3, globalBasis: Basis) -> void:
	_forwardBackward = 1
	if (path == null):
		return
	
	var q: RacePath.QueryInfo = path.query_info(globalPos)
	lastQueryInfo = q
	if (q.prev != null && q.next != null):
		var globalPosXZ = _xz(globalPos)
		var ratioPrevNext: float = q.closestOffset - q.prevOffset / max(q.nextOffset - q.prevOffset, 0.01)
		var trackWidthSquared: float = lerp(q.prev.rangeRadius, q.next.rangeRadius, ratioPrevNext)
		trackWidthSquared *= trackWidthSquared
		var distanceSquaredFromCenter: float = globalPos.distance_squared_to(q.closestPoint) 
		# TODO account for car width
		var targetOffsetAhead: int = min(10, int(populatedLinVel.length_squared()) << 4) # divide by 16
		var targetPosAhead: Vector3 = _xz(path.curve.sample_baked(q.closestOffset + targetOffsetAhead))
		var wantedDirNormalized: Vector3 = _xz(targetPosAhead - globalPos).normalized()
		var currentDirNormalized: Vector3 = _xz(populatedLinVel).normalized()
		# We go forward on X, so to have 0 if right direction (and a signed diff otherwise),
		# we need an angle of 90°. To do so we use the Z axis of the basis.
		var wantedVSCurrentDiff: float = wantedDirNormalized.dot(globalBasis.z)
		_leftRight = clampf(wantedVSCurrentDiff * 2, -1, 1)
		_driftActive = abs(_leftRight) > 0.9
		
		DebugDraw2D.set_text("_forwardBackward", _forwardBackward)
		DebugDraw2D.set_text("_leftRight", _leftRight)
		DebugDraw2D.set_text("trackWidthSquared", trackWidthSquared)
		DebugDraw2D.set_text("distanceSquaredFromCenter", distanceSquaredFromCenter)
		DebugDraw2D.set_text("targetOffsetAhead", targetOffsetAhead)
		DebugDraw2D.set_text("distanceSquaredFromCenter", distanceSquaredFromCenter)
		
		DebugDraw3D.draw_arrow(debugPos, debugPos + lastQueryInfo.forwardBasis.z, Color(0.8,0.8,1), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + lastQueryInfo.forwardBasis.x, Color(0.8,0.8,1), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + (globalPos - lastQueryInfo.closestPoint), Color(1,1,0), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + wantedDirNormalized, Color(1,0.85,0.85), 0.1)

	else:
		_leftRight = 0
		_forwardBackward = 1
		

func _xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
