# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


extends RigidBody3D
var currentDirection: Vector3 = Vector3(1,0,0)
@export var accelerationForce: float = 5000
@export var rotationForce: float = 100
@export var speedMultiplier: float = 1.0
@export var springStrength: float = 150000 # 100000
@export var springDamping: float = 15000 # 12000 # coefficient
@export var restDistance: float = 0.7
@export var maxSpeedMetersPerSecond: float = 25:
	set(v):
		maxSpeedMetersPerSecond = v
		_maxSpeedSquared = v*v

var _debugCentrifugusForce: Vector3
var _debugSlidingForce: Vector3
var _debugSoftClampSpeedForce: Vector3
var _forcedBasis: Basis
var _mustForceBasis: bool = false
var wheelRayCasts: Array[RayCast3D]
var _maxSpeedSquared: float:
	get():
		return maxSpeedMetersPerSecond * maxSpeedMetersPerSecond
var _drifting = false
var _driftingDirection: float = 0 # 1 or -1, see signf()

func _ready() -> void:
	wheelRayCasts = [$WheelFRRayCast3D, $WheelBLRayCast3D, $WheelBRRayCast3D, $WheelFLRayCast3D]
	# actual damping / critical damping (critical = best)
	var dampingRatio: float = springDamping / (2 * sqrt(mass * springStrength))
	print("current vehicle damping ratio (1 is best/critical damping, <1 is underdamped, >1 is overdamped): ", dampingRatio)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if (_mustForceBasis):
		_mustForceBasis = false
		state.transform.basis = _forcedBasis.orthonormalized()
	var forwardBackward: float = Input.get_axis("backward", "forward")
	if (forwardBackward < 0):
		forwardBackward *= 0.1 # softer brake and slow backward speed
	var leftRight: float = Input.get_axis("left", "right")
	
	var startsDrifting = Input.is_action_just_pressed("drift")
	var stopsDrifting = Input.is_action_just_released("drift")
	if startsDrifting:
		_drifting = true
		_driftingDirection = signf(leftRight)
	if stopsDrifting:
		_drifting = false
	if _drifting:
		leftRight = (leftRight * 0.75) + 1 * _driftingDirection # 0.25 to 1.75 in given direction

	_cancel_inertia(state)
	_apply_wheel_adherence(state)

	state.apply_central_force((forwardBackward * accelerationForce * speedMultiplier * global_basis.x))
	state.apply_torque(leftRight * rotationForce * Vector3(0,-1,0))
	
	for wheelRayCast in wheelRayCasts:
		_apply_single_wheel_suspension(wheelRayCast)

	_soft_clamp_speed(state)



func _soft_clamp_speed(state: PhysicsDirectBodyState3D):
	var velSquaredXZ: float = (state.linear_velocity * Vector3(1,0,1)).length_squared()
	if (velSquaredXZ > _maxSpeedSquared):
		var normProjectedOnXZ: Vector3 = state.linear_velocity.normalized() * Vector3(1,0,1)
		var diff: float = (velSquaredXZ - _maxSpeedSquared)
		# This is a physics based "clamp", being quadratic to be as close as possible to a hard limit.
		# We do not use clamp as it causes unexpected behavior, such as making the car drift in air.
		# It does not affect fall speed.
		_debugSoftClampSpeedForce = -normProjectedOnXZ * diff * diff
		state.apply_central_force(_debugSoftClampSpeedForce)
		#state.linear_velocity = state.linear_velocity.clamp(norm, norm * maxSpeedMetersPerSecond)
	else:
		_debugSoftClampSpeedForce = Vector3(0,0,0)

func _get_point_velocity(point: Vector3) -> Vector3:
	# physics formula
	return linear_velocity + angular_velocity.cross(point - global_position)

# CHECK THIS FOR SUSPENSION: https://www.youtube.com/watch?v=9MqmFSn1Rlw
func _apply_single_wheel_suspension(suspensionRay: RayCast3D) -> void:
	if suspensionRay.is_colliding():
		var contactPoint: Vector3 = suspensionRay.get_collision_point()
		var springUpDirection: Vector3 = suspensionRay.global_transform.basis.y # from wheel perspective, not world
		var springCurrentLength: float = suspensionRay.global_position.distance_to(contactPoint)
		var offset: float = restDistance - springCurrentLength
		
		# push if compressed, pull if extended and within ray range
		var springForce: float = springStrength * offset
		
		# damping force = damping * relative velocity
		var worldVelocity: Vector3 = _get_point_velocity(contactPoint)
		var relativeVelocity: float = springUpDirection.dot(worldVelocity)
		var springDampingForce: float = springDamping * relativeVelocity
		
		# convert to 3d directional vector (align force along the push/pull axis of the spring/raycast
		var springForceVector: Vector3 = (springForce - springDampingForce) * springUpDirection
		
		var forcePositionOffset = contactPoint - global_position # at raycast collision point
		apply_force(springForceVector, forcePositionOffset)



# applied on x,z plan
func _cancel_inertia(state: PhysicsDirectBodyState3D) -> void:
	var radius: float = _get_radius_of_rotation(state)
	var centrifugusDirection: Vector3 = global_basis.z.normalized() * sign(state.angular_velocity.y)
	if (centrifugusDirection.length() < 0.01):
		return
	var centrifugusForce: Vector3 = centrifugusDirection * (mass * state.linear_velocity.length_squared() / radius)
	state.apply_central_force(-centrifugusForce)
	_debugCentrifugusForce = centrifugusForce

# applied on x,z plan
func _get_radius_of_rotation(state: PhysicsDirectBodyState3D) -> float:
	# assuming a circle arc of length <previous pos to current pos>,
	# of angle length equal to previous angular velocity,
	# we compute the circumference of the entire circle,
	# and deduct a radius from there
	var length = (state.linear_velocity * Vector3(1,0,1)).length()
	var angle = abs(state.angular_velocity.y)
	var circumference = (2*PI / angle) * length
	var radius = circumference / (2*PI)
	return radius

# FIXME broken!!!
func _apply_wheel_adherence(state: PhysicsDirectBodyState3D) -> void:
	if (_wheels_on_ground() < 2):
		_debugSlidingForce = Vector3(0,0,0)
		return
	var normalToGround: Vector3 = global_basis.y.normalized()
	var groundCounterForce: Vector3 = normalToGround * (get_gravity()).length()
	var slidingForce: Vector3 = (get_gravity() + groundCounterForce) * mass
	_debugSlidingForce = slidingForce
	var z: Vector3 = global_basis.z.normalized()
	state.apply_central_force(z * -slidingForce.dot(z))

func _wheels_on_ground() -> int:
	var wheelsOnGround: int = 0
	if ($WheelFRRayCast3D.is_colliding()):
		wheelsOnGround += 1
	if ($WheelBLRayCast3D.is_colliding()):
		wheelsOnGround += 1
	if ($WheelBRRayCast3D.is_colliding()):
		wheelsOnGround += 1
	if ($WheelFLRayCast3D.is_colliding()):
		wheelsOnGround += 1
		
	return wheelsOnGround

func _input(event):
	if (event.is_action_pressed("toggle_cam")):
		$Camera3D.current = !$Camera3D.current

func _process(_delta: float) -> void:
	# debug
	var debugPos = global_position + Vector3(0,3,0)
	DebugDraw3D.draw_arrow(debugPos, debugPos + linear_velocity, Color(0,0,1), 0.1)
	DebugDraw2D.set_text("Velocity", "%0.2f" % linear_velocity.length())
	DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	DebugDraw3D.draw_arrow(debugPos, debugPos + _debugCentrifugusForce, Color(0,1,0), 0.1)
	DebugDraw3D.draw_arrow(debugPos, debugPos + _debugSlidingForce, Color(1,0,0), 0.1)
	DebugDraw3D.draw_arrow(debugPos, debugPos + _debugSoftClampSpeedForce, Color(1,0,1), 0.1)

func force_basis_on_next_physics_frame(basis: Basis):
	_forcedBasis = basis
	_mustForceBasis = true
