# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


extends RigidBody3D



var currentDirection: Vector3 = Vector3(1,0,0)
@export var showDebugArrows: bool = false
@export var accelerationForce: float = 5000
@export var rotationForce: float = 100
@export var speedMultiplier: float = 1.0
@export var springStrength: float = 150000 # 100000
@export var springDamping: float = 15000 # 12000 # coefficient
@export var restDistance: float = 0.7
@export var maxSpeedMetersPerSecond: float = 25
@export var maxSpeedOutOfBounds: float = 8
@export var interface: CarCustomPhysics2
@export var mode: CarCustomPhysics2.CarMode:
	set(v):
		mode = v
		if (v == CarCustomPhysics2.CarMode.USER):
			_brain = UserBrain.new()
		if (v == CarCustomPhysics2.CarMode.BOT):
			_brain = BotBrain.new()
		_brain.showDebugArrows = showDebugArrows
@export var path: RacePath:
	set(v):
		path = v
		if (_brain != null):
			_brain.path = v

const DRIFT_LEFT_RIGHT_FACTOR: float = 0.75
const DRIFT_ADDED_DIRECTION_MULTIPLIER: float = 1

const BRAKE_FORCE_FACTOR: float = 0.1
const BACKWARDS_FORCE_FACTOR: float = 0.20
const MIN_SPEED_FOR_BEING_BRAKE_SQUARED: float = 4

const DIRECTION_NERF_IN_AIR: float = 0.1
const FORWARD_BACKWARD_NERF_IN_AIR: float = 0.1

const DEBUG_JUMP_FORCE: float = 5000

# crash avoidance related constants
const MIN_INERTIA_RADIUS_LIMIT = 0.001
const MAX_INERTIA_RADIUS_LIMIT = 10_000
const MIN_ANGLE_THRESHOLD = 0.01

var _debugCentrifugusForce: Vector3
var _debugSlidingForce: Vector3
var _debugSoftClampSpeedForce: Vector3
var _forcedBasis: Basis
var _mustForceBasis: bool = false
var wheelRayCasts: Array[RayCast3D]
var _groundRaycast: RayCast3D
var _drifting = false:
	set(v):
		_drifting = v
		interface.driftingEffects = v
var _driftingDirection: float = 0 # 1 or -1, see signf()
var _brain: ACarBrain
var _cam: Camera3D

func _ready() -> void:
	_cam = $Camera3D
	assert(_cam != null, "ERROR: No cam configured on the car.")
	assert(interface != null, "ERROR: interface not assigned.")
	wheelRayCasts = [$WheelFRRayCast3D, $WheelBLRayCast3D, $WheelBRRayCast3D, $WheelFLRayCast3D]
	for r in wheelRayCasts:
		assert(r != null, "ERROR: a wheel raycast was not found.")
	_groundRaycast = $GroundRayCast3D
	assert(_groundRaycast != null, "ERROR: ground raycast not found.")
	# actual damping / critical damping (critical = best)
	assert(mass > 0, "ERROR: mass should not be greater than zero.")
	assert(springStrength > 0, "ERROR: springSrength should be greater than zero.")
	var dampingRatio: float = springDamping / (2 * sqrt(mass * springStrength))
	print("current vehicle damping ratio (1 is best/critical damping, <1 is underdamped, >1 is overdamped): ", dampingRatio)
	
	$ManagedFreezeWakeUpArea3D.body_entered.connect(func (body: Node3D):
		if (is_instance_of(body, FreezeManagedRigidBody3D)):
			var typedBody: FreezeManagedRigidBody3D = body
			typedBody.managedFreeze = false
	)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if (_brain == null):
		return
		
	var debugPos = global_position + Vector3(0,3,0)
	_brain.tick(global_position, debugPos, global_basis, basis, $FrontRayCast3D.is_colliding(), $GroundRayCast3D.is_colliding())
	
	if (_mustForceBasis):
		_mustForceBasis = false
		state.transform.basis = _forcedBasis.orthonormalized()
		_disable_drift()
		state.linear_velocity = Vector3(0,0,0)
		state.angular_velocity = Vector3(0,0,0)
	var forwardBackward: float = _brain.get_forward_backward_axis()
	if (forwardBackward < 0):
		var goingForward: bool
		# we want to avoid an invalid vector with (0,0,0).normalized()
		if (state.linear_velocity.length_squared() > 0.01):
			goingForward = global_basis.x.dot(state.linear_velocity.normalized()) > 0
		else:
			goingForward = false
		var goingFast: bool = state.linear_velocity.length_squared() > MIN_SPEED_FOR_BEING_BRAKE_SQUARED
		var isBraking: bool = goingForward && goingFast
		if (isBraking):
			forwardBackward *= BRAKE_FORCE_FACTOR # softer brake and slow backward speed
		else:
			forwardBackward *= BACKWARDS_FORCE_FACTOR
	var leftRight: float = _brain.get_left_right_axis()
	var onGround: bool = _groundRaycast.is_colliding()
	var outOfBounds = false
	if (onGround):
		var collider: CollisionObject3D = _get_collider_of_colliding_raycast(_groundRaycast)
		if (collider != null):
			var collidesOutOfBoundsMask: bool = !collider.get_collision_layer_value(5)
			outOfBounds = collidesOutOfBoundsMask
	
	var wantToDrift = _brain.drift_input_active()
	# cannot drift when not turning, or if already drifting in a direction.
	if wantToDrift && abs(leftRight) > 0 && _driftingDirection == 0 && onGround:
		_drifting = true
		_driftingDirection = signf(leftRight)
	if !wantToDrift && _drifting:
		_disable_drift()
	if _drifting:
		# example: if left right factor is 0.75 and added direction multiplier is 1, the range is:
		# 0.25 to 1.75 in given direction
		leftRight = (leftRight * DRIFT_LEFT_RIGHT_FACTOR) + DRIFT_ADDED_DIRECTION_MULTIPLIER * _driftingDirection

	if !onGround:
		leftRight *= DIRECTION_NERF_IN_AIR
		forwardBackward *= FORWARD_BACKWARD_NERF_IN_AIR

	if (Input.is_action_just_pressed("debug_jump")):
		state.apply_impulse(Vector3(0,DEBUG_JUMP_FORCE,0))

	_cancel_inertia(state)
	_apply_wheel_adherence(state)

	state.apply_central_force((forwardBackward * accelerationForce * speedMultiplier * global_basis.x))
	state.apply_torque(leftRight * rotationForce * Vector3(0,-1,0))
	
	for wheelRayCast in wheelRayCasts:
		_apply_single_wheel_suspension(wheelRayCast)

	_soft_clamp_speed(state, outOfBounds)
	_brain.populatedLinVel = state.linear_velocity
	_brain.populatedAngVel = state.angular_velocity

func _disable_drift() -> void:
	_drifting = false
	_driftingDirection = 0
	
func _get_max_speed_squared(outOfBounds: bool):
	if (outOfBounds):
		return maxSpeedOutOfBounds * maxSpeedOutOfBounds
	else:
		return maxSpeedMetersPerSecond * maxSpeedMetersPerSecond

func _soft_clamp_speed(state: PhysicsDirectBodyState3D, outOfBounds: bool):
	var velSquaredXZ: float = (state.linear_velocity * Vector3(1,0,1)).length_squared()
	var maxSpeedSquared = _get_max_speed_squared(outOfBounds)
	if (velSquaredXZ > maxSpeedSquared):
		var normProjectedOnXZ: Vector3 = state.linear_velocity.normalized() * Vector3(1,0,1)
		var diff: float = (velSquaredXZ - maxSpeedSquared)
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
		return # TODO might be the cause of bugs when going backwards?
	var cappedRadius = min(max(radius, MIN_INERTIA_RADIUS_LIMIT), MAX_INERTIA_RADIUS_LIMIT)
	var centrifugusForce: Vector3 = centrifugusDirection * (mass * state.linear_velocity.length_squared() / cappedRadius)
	state.apply_central_force(-centrifugusForce)
	_debugCentrifugusForce = centrifugusForce

# applied on x,z plan
func _get_radius_of_rotation(state: PhysicsDirectBodyState3D) -> float:
	# assuming a circle arc of length <previous pos to current pos>,
	# of angle length equal to previous angular velocity,
	# we compute the circumference of the entire circle,
	# and deduct a radius from there
	var length = (state.linear_velocity * Vector3(1,0,1)).length()
	var angle = max(abs(state.angular_velocity.y), MIN_ANGLE_THRESHOLD) # avoid 0 to avoid division by zero crash
	var circumference = (2*PI / angle) * length
	var radius = circumference / (2*PI)
	return radius

# FIXME broken!!!
func _apply_wheel_adherence(state: PhysicsDirectBodyState3D) -> void:
	if (_wheels_on_ground() < 2):
		_debugSlidingForce = Vector3(0,0,0)
		return
	var normalToGround: Vector3 = global_basis.y.normalized()
	assert(normalToGround.length_squared() > 0)
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
	
	if (_cam.current):
		DebugDraw2D.set_text("Velocity", "%0.2f" % linear_velocity.length())
		DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	if (showDebugArrows):
		DebugDraw3D.draw_arrow(debugPos, debugPos + linear_velocity, Color(0,0,1), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + _debugCentrifugusForce, Color(0,1,0), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + _debugSlidingForce, Color(1,0,0), 0.1)
		DebugDraw3D.draw_arrow(debugPos, debugPos + _debugSoftClampSpeedForce, Color(1,0,1), 0.1)

func force_basis_on_next_physics_frame(basis: Basis):
	_forcedBasis = basis
	_mustForceBasis = true
	
## Returns null if the type do not match.
func _get_collider_of_colliding_raycast(raycast: RayCast3D) -> CollisionObject3D:
	assert(raycast.is_colliding(), "ERROR: raycast not colliding.")
	# from godot documentation:
	var target = raycast.get_collider() # A CollisionObject3D.
	if (is_instance_of(target, CollisionObject3D)):
		return target
	else:
		return null
