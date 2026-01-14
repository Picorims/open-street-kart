# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


extends RigidBody3D


var current_direction: Vector3 = Vector3(1, 0, 0)
@export var show_debug_arrows: bool = false
@export var acceleration_force: float = 6_000
@export var rotation_force: float = 100
@export var speed_multiplier: float = 1.0
@export var spring_strength: float = 250_000
@export var spring_damping: float = 21_000 # coefficient
@export var rest_distance: float = 0.5
@export var max_speed_meters_per_second: float = 25
@export var max_speed_out_of_bounds_meters_per_second: float = 8
@export var interface: CarCustomPhysics2
@export var mode: CarCustomPhysics2.CarMode:
	set(v):
		mode = v
		if (v == CarCustomPhysics2.CarMode.USER):
			_brain = UserBrain.new()
		if (v == CarCustomPhysics2.CarMode.BOT):
			_brain = BotBrain.new()
		_brain.show_debug_arrows = show_debug_arrows
@export var path: RacePath:
	set(v):
		path = v
		if (_brain != null):
			_brain.path = v

const DRIFT_LEFT_RIGHT_FACTOR: float = 0.75
const DRIFT_ADDED_DIRECTION_MULTIPLIER: float = 1

const BRAKE_FORCE_FACTOR: float = 0.1
const BACKWARDS_FORCE_FACTOR: float = 0.70
const MIN_SPEED_FOR_BEING_BRAKE_SQUARED: float = 4

const DIRECTION_NERF_IN_AIR: float = 0.1
const FORWARD_BACKWARD_NERF_IN_AIR: float = 0.1

const DEBUG_JUMP_FORCE: float = 5000

const RESPAWN_BOT_AFTER_STUCK_FOR_SECONDS: float = 5
const IS_STUCK_SPEED_SQUARED_THRESHOLD: float = 1

# crash avoidance related constants
const MIN_INERTIA_RADIUS_LIMIT = 0.001
const MAX_INERTIA_RADIUS_LIMIT = 10_000
const MIN_YAW_THRESHOLD_FOR_CENTRIFUGAL_FORCE_COMPUTE = 0.03
const MAX_LIN_VEL_FOR_CENTRIFUGAL_FORCE_COMPUTE = 100

const SPEED_BOOST = 1.5

var _track_state: TrackState

var _debug_centrifugal_force: Vector3
var _debug_sliding_force: Vector3
var _debug_sliding_force_compensated: Vector3
var _debug_soft_clamp_speed_force: Vector3
var _forced_basis: Basis
var _must_force_basis: bool = false
var wheel_ray_casts: Array[RayCast3D]
var _going_backwards: bool = false
var _ground_raycast: RayCast3D
var _drifting = false:
	set(v):
		_drifting = v
		interface.drifting_effects = v
var _drifting_direction: float = 0 # 1 or -1, see signf()
var _now_seconds: float = 0
var _speed_boost_until_seconds: float = -1
var _brain: ACarBrain
var _cam: Camera3D
var _time_since_not_moving_seconds: float = 0
var _last_xz_speed_squared: float = 0

func get_race_path_offset() -> float:
	return _brain.last_query_info.closest_offset

func is_in_speed_boost() -> bool:
	return _now_seconds < _speed_boost_until_seconds

func _ready() -> void:
	_cam = $Camera3D
	assert(_cam != null, "ERROR: No cam configured on the car.")
	assert(interface != null, "ERROR: interface not assigned.")
	wheel_ray_casts = [$WheelFRRayCast3D, $WheelBLRayCast3D, $WheelBRRayCast3D, $WheelFLRayCast3D]
	for r in wheel_ray_casts:
		assert(r != null, "ERROR: a wheel raycast was not found.")
	_ground_raycast = $GroundRayCast3D
	assert(_ground_raycast != null, "ERROR: ground raycast not found.")
	# actual damping / critical damping (critical = best)
	assert(mass > 0, "ERROR: mass should not be greater than zero.")
	assert(spring_strength > 0, "ERROR: springSrength should be greater than zero.")
	var damping_ratio: float = spring_damping / (2 * sqrt(mass * spring_strength))
	print("current vehicle damping ratio (1 is best/critical damping, <1 is under-damped, >1 is over-damped): ", damping_ratio)
	
	_track_state = get_tree().get_first_node_in_group("track_state")
	assert(_track_state != null, "Track state not found.")
	
	$ManagedFreezeWakeUpArea3D.body_entered.connect(func(body: Node3D):
		if (is_instance_of(body, FreezeManagedRigidBody3D)):
			var typedBody: FreezeManagedRigidBody3D = body
			typedBody.managed_freeze = false
	)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if (_brain == null):
		return
			
	if (_must_force_basis):
		_must_force_basis = false
		state.transform.basis = _forced_basis.orthonormalized()
		_disable_drift()
		state.linear_velocity = Vector3(0, 0, 0)
		state.angular_velocity = Vector3(0, 0, 0)
	var forward_backward: float = _brain.get_forward_backward_axis()
	if (forward_backward < 0): # if backwards force
		var going_forward: bool
		# we want to avoid an invalid vector with (0,0,0).normalized()
		if (state.linear_velocity.length_squared() > 0.01):
			going_forward = global_basis.x.dot(state.linear_velocity.normalized()) > 0
		else:
			going_forward = false
		var going_fast: bool = state.linear_velocity.length_squared() > MIN_SPEED_FOR_BEING_BRAKE_SQUARED
		var is_braking: bool = going_forward and going_fast
		if (is_braking):
			forward_backward *= BRAKE_FORCE_FACTOR # softer brake and slow backward speed
			_going_backwards = false
		else:
			forward_backward *= BACKWARDS_FORCE_FACTOR
			_going_backwards = true
	else:
		_going_backwards = false
	var left_right: float = _brain.get_left_right_axis()
	var on_ground: bool = _ground_raycast.is_colliding()
	var out_of_bounds = false
	if (on_ground):
		var collider: CollisionObject3D = _get_collider_of_colliding_raycast(_ground_raycast)
		if (collider != null):
			out_of_bounds = collider.get_collision_layer_value(4)
	
	var want_to_drift = _brain.drift_input_active()
	# cannot drift when not turning, or if already drifting in a direction.
	if want_to_drift and abs(left_right) > 0 and _drifting_direction == 0 and on_ground:
		_drifting = true
		_drifting_direction = signf(left_right)
	if (not want_to_drift) and _drifting:
		_disable_drift()
	if _drifting:
		# example: if left right factor is 0.75 and added direction multiplier is 1, the range is:
		# 0.25 to 1.75 in given direction
		left_right = (left_right * DRIFT_LEFT_RIGHT_FACTOR) + DRIFT_ADDED_DIRECTION_MULTIPLIER * _drifting_direction

	if not on_ground:
		left_right *= DIRECTION_NERF_IN_AIR
		forward_backward *= FORWARD_BACKWARD_NERF_IN_AIR

	if (Input.is_action_just_pressed("debug_jump")):
		state.apply_impulse(Vector3(0, DEBUG_JUMP_FORCE, 0))

	_cancel_inertia(state)
	_apply_wheel_adherence(state)

	state.apply_central_force((forward_backward * acceleration_force * speed_multiplier * global_basis.x))
	if (is_in_speed_boost()):
		state.apply_central_force(acceleration_force * 2 * speed_multiplier * global_basis.x)
	state.apply_torque(left_right * rotation_force * Vector3(0, -1, 0))
	
	for wheelRayCast in wheel_ray_casts:
		_apply_single_wheel_suspension(wheelRayCast)

	_soft_clamp_speed(state, out_of_bounds)
	_brain.populated_lin_vel = state.linear_velocity
	_brain.populated_ang_vel = state.angular_velocity

func _disable_drift() -> void:
	_drifting = false
	_drifting_direction = 0
	
func _get_max_speed_squared(out_of_bounds: bool):
	var final_speed = 0
	if (out_of_bounds and not is_in_speed_boost()) or _going_backwards:
		final_speed = max_speed_out_of_bounds_meters_per_second
	elif is_in_speed_boost():
		final_speed = max_speed_meters_per_second * SPEED_BOOST
	else:
		final_speed = max_speed_meters_per_second
	return final_speed * final_speed

func _soft_clamp_speed(state: PhysicsDirectBodyState3D, out_of_bounds: bool):
	var vel_squared_xz: float = (state.linear_velocity * Vector3(1, 0, 1)).length_squared()
	_last_xz_speed_squared = vel_squared_xz
	var max_speed_squared = _get_max_speed_squared(out_of_bounds)
	if (vel_squared_xz > max_speed_squared):
		var norm_projected_on_xz: Vector3 = state.linear_velocity.normalized() * Vector3(1, 0, 1)
		# Capping to half the current speed to avoid abrupt changes (like straight up stopping
		# the car after a speed boost end while being out of bounds in "crazy" speed mode (~40m/s)).
		var diff: float = min(vel_squared_xz * 0.5, vel_squared_xz - max_speed_squared)
		# This is a physics based "clamp", being quadratic to be as close as possible to a hard limit.
		# We do not use clamp as it causes unexpected behavior, such as making the car drift in air.
		# It does not affect fall speed.
		_debug_soft_clamp_speed_force = - norm_projected_on_xz * diff * diff
		state.apply_central_force(_debug_soft_clamp_speed_force)
		#state.linear_velocity = state.linear_velocity.clamp(norm, norm * max_speed_meters_per_second)
	else:
		_debug_soft_clamp_speed_force = Vector3(0, 0, 0)

func _get_point_velocity(point: Vector3) -> Vector3:
	# physics formula
	return linear_velocity + angular_velocity.cross(point - global_position)

# CHECK THIS FOR SUSPENSION: https://www.youtube.com/watch?v=9MqmFSn1Rlw
func _apply_single_wheel_suspension(suspension_ray: RayCast3D) -> void:
	if suspension_ray.is_colliding():
		var contact_point: Vector3 = suspension_ray.get_collision_point()
		var spring_up_direction: Vector3 = suspension_ray.global_transform.basis.y # from wheel perspective, not world
		var spring_current_length: float = suspension_ray.global_position.distance_to(contact_point)
		var offset: float = rest_distance - spring_current_length
		
		# push if compressed, pull if extended and within ray range
		var spring_force: float = spring_strength * offset
		
		# damping force = damping * relative velocity
		var world_velocity: Vector3 = _get_point_velocity(contact_point)
		var relative_velocity: float = spring_up_direction.dot(world_velocity)
		var spring_damping_force: float = spring_damping * relative_velocity
		
		# convert to 3d directional vector (align force along the push/pull axis of the spring/raycast
		var spring_force_vector: Vector3 = (spring_force - spring_damping_force) * spring_up_direction
		
		var force_position_offset = contact_point - global_position # at raycast collision point
		if (
			is_nan(force_position_offset.x) or is_nan(force_position_offset.y) or is_nan(force_position_offset.z)
			or is_nan(spring_force_vector.x) or is_nan(spring_force_vector.y) or is_nan(spring_force_vector.z)
		):
			push_warning("NaN detected in force_position_offset in _apply_single_wheel_suspension: " + str(force_position_offset))
			return # avoid crash
		apply_force(spring_force_vector, force_position_offset)


# applied on x,z plan
func _cancel_inertia(state: PhysicsDirectBodyState3D) -> void:
	var radius: float = _get_radius_of_rotation(state)
	if (radius == -1): # see doc for _get_radius_of_rotation()
		return
	if (state.linear_velocity.length_squared() < 0.01):
		# Not significant, also reduces the risk of problematic values.
		return
	# Projecting the linear velocity onto the forward / backward axis to know in which direction the car
	# goes, assuming wheel adherence.
	var forward_backward_lin_vel_direction: float = sign(state.linear_velocity.dot(global_basis.x))
	var rotation_direction: float = signf(state.angular_velocity.y)
	var centrifugal_direction: Vector3 = global_basis.z.normalized() * rotation_direction * forward_backward_lin_vel_direction
	if (centrifugal_direction.length() < 0.01):
		return
	var capped_radius: float = min(max(radius, MIN_INERTIA_RADIUS_LIMIT), MAX_INERTIA_RADIUS_LIMIT)
	var centrifugal_force: Vector3 = centrifugal_direction * (mass * state.linear_velocity.length_squared() / capped_radius)
	var counter_force: Vector3 = - centrifugal_force
	if (_drifting):
		counter_force *= 0.7
	state.apply_central_force(counter_force)
	_debug_centrifugal_force = centrifugal_force

## If the rigid body is turning, it is following a circle with a center of attraction,
## defining the centrifugal force. This function returns the radius of such circle based
## on the angular velocity (on Y; yaw), and linear velocity. (Imagining an arc from origin
## to new position after angular velocity is applied, with the arc length based on linear velocity,
## the circle is bigger as the velocity increases)
##
## Returns -1 if the circle is too big and would cause infinite values (too small angular velocity,
## or too big linear velocity)
## 
## Applied on x,z plan
func _get_radius_of_rotation(state: PhysicsDirectBodyState3D) -> float:
	# assuming a circle arc of length <previous pos to current pos>,
	# of angle length equal to previous angular velocity,
	# we compute the circumference of the entire circle,
	# and deduct a radius from there
	var length: float = (state.linear_velocity * Vector3(1, 0, 1)).length()
	var yaw: float = absf(state.angular_velocity.y)
	# avoid 0 to avoid division by zero crash
	var yaw_too_small: bool = yaw < MIN_YAW_THRESHOLD_FOR_CENTRIFUGAL_FORCE_COMPUTE
	var length_too_big: bool = length > MAX_LIN_VEL_FOR_CENTRIFUGAL_FORCE_COMPUTE
	if (yaw_too_small or length_too_big):
		return -1
	var circumference = (2 * PI / yaw) * length
	var radius = circumference / (2 * PI)
	return radius

# FIXME broken!!!
func _apply_wheel_adherence(state: PhysicsDirectBodyState3D) -> void:
	if (_wheels_on_ground() < 2):
		_debug_sliding_force = Vector3(0, 0, 0)
		return
	var normal_to_ground: Vector3 = global_basis.y.normalized()
	assert(normal_to_ground.length_squared() > 0)
	var ground_counter_force: Vector3 = normal_to_ground * (get_gravity()).length()
	var sliding_force: Vector3 = (get_gravity() + ground_counter_force) * mass
	_debug_sliding_force = sliding_force
	var z: Vector3 = global_basis.z.normalized()
	var compensating_force: Vector3 = z * -sliding_force.dot(z)
	_debug_sliding_force_compensated = compensating_force
	state.apply_central_force(compensating_force)

func _wheels_on_ground() -> int:
	var wheels_on_ground: int = 0
	if ($WheelFRRayCast3D.is_colliding()):
		wheels_on_ground += 1
	if ($WheelBLRayCast3D.is_colliding()):
		wheels_on_ground += 1
	if ($WheelBRRayCast3D.is_colliding()):
		wheels_on_ground += 1
	if ($WheelFLRayCast3D.is_colliding()):
		wheels_on_ground += 1
		
	return wheels_on_ground

func _input(event):
	if (event.is_action_pressed("toggle_cam")):
		$Camera3D.current = not $Camera3D.current

func _process(delta: float) -> void:
	interface.speed_boost_effects = is_in_speed_boost()
	
	if abs(_last_xz_speed_squared) < IS_STUCK_SPEED_SQUARED_THRESHOLD:
		_time_since_not_moving_seconds += delta
	else:
		_time_since_not_moving_seconds = 0
	if _time_since_not_moving_seconds > RESPAWN_BOT_AFTER_STUCK_FOR_SECONDS and is_instance_of(_brain, BotBrain):
		_time_since_not_moving_seconds = 0
		interface.respawn()
	
	_track_state.get_track_region_manager().poll_coord(global_position)
	
	# debug =============================
	var debug_pos = global_position + Vector3(0, 3, 0)
	if (_cam.current):
		DebugDraw2D.set_text("Velocity", "%0.2f" % linear_velocity.length())
		DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	if (show_debug_arrows):
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + linear_velocity, Color(0, 0, 1), 0.1)
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_centrifugal_force, Color(0, 1, 0), 0.1)
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_sliding_force, Color(1, 0, 0), 0.1)
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_sliding_force_compensated, Color(1, 0, 0.5), 0.1)
		DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_soft_clamp_speed_force, Color(1, 0, 1), 0.1)

var _elapsed: float = 0
func _physics_process(delta: float) -> void:
	_elapsed += delta
	_now_seconds += delta
	if (_elapsed > 0.02):
		_elapsed = 0
		var debug_pos = global_position + Vector3(0, 3, 0)
		_brain.tick(global_position, debug_pos, global_basis, basis, $FrontRayCast3D.is_colliding(), $GroundRayCast3D.is_colliding())


func force_basis_on_next_physics_frame(new_basis: Basis):
	_forced_basis = new_basis
	_must_force_basis = true

func clear_speed_boost():
	_speed_boost_until_seconds = -1
	
## Returns null if the type do not match.
func _get_collider_of_colliding_raycast(raycast: RayCast3D) -> CollisionObject3D:
	assert(raycast.is_colliding(), "ERROR: raycast not colliding.")
	# from godot documentation:
	var target = raycast.get_collider() # A CollisionObject3D.
	if (is_instance_of(target, CollisionObject3D)):
		return target
	else:
		return null

func apply_speed_boost_seconds(seconds: float):
	_speed_boost_until_seconds = max(_speed_boost_until_seconds, _now_seconds + seconds)
