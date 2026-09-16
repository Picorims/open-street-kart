# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


extends Node3D


var current_direction: Vector3 = Vector3(1, 0, 0)
@export var show_debug_arrows: bool = false
@export var acceleration_force: float = 9_000
@export var rotation_force: float = 100
@export var speed_multiplier: float = 1.0
@export var spring_strength: float = 250_000
@export var spring_damping: float = 21_000 # coefficient
@export var rest_distance: float = 0.5
@export var max_speed_meters_per_second: float = 25
@export var max_speed_out_of_bounds_meters_per_second: float = 8
@export var interface: CarCustomPhysics2Client
@export var mode: CarCustomPhysics2Client.CarMode: #FIXME shared enum?
	set(v):
		mode = v
		if (v == CarCustomPhysics2Client.CarMode.USER):
			_brain = UserBrain.new()
		if (v == CarCustomPhysics2Client.CarMode.BOT):
			_brain = BotBrain.new()
		_brain.show_debug_arrows = show_debug_arrows
@export var path: RacePath:
	set(v):
		path = v
		if (_brain != null):
			_brain.path = v
var items_holder: Node3D = null
var current_velocity := Vector3.ZERO
var current_position := Vector3.ZERO

const AIR_BOMB_SCENE: PackedScene = preload("res://prefabs/items/air_bomb.tscn")

const DRIFT_LEFT_RIGHT_FACTOR: float = 1.2
const DRIFT_ADDED_DIRECTION_MULTIPLIER: float = 1.6

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

var _track_state: TrackStateServer

var _debug_centrifugal_force: Vector3
var _debug_sliding_force: Vector3
var _debug_sliding_force_compensated: Vector3
var _debug_soft_clamp_speed_force: Vector3
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
var _time_since_not_moving_seconds: float = 0
var _last_xz_speed_squared: float = 0

func get_race_path_offset() -> float:
	return _brain.last_query_info.closest_offset

func is_in_speed_boost() -> bool:
	return _now_seconds < _speed_boost_until_seconds

func _ready() -> void:
	assert(interface != null, "ERROR: interface not assigned.")
	
	_track_state = get_tree().get_first_node_in_group("track_state")
	assert(_track_state != null, "Track state not found.")
	
	current_position = global_position

func _disable_drift() -> void:
	_drifting = false
	_drifting_direction = 0

func _process(delta: float) -> void:
	interface.speed_boost_effects = is_in_speed_boost()
	
	if abs(_last_xz_speed_squared) < IS_STUCK_SPEED_SQUARED_THRESHOLD:
		_time_since_not_moving_seconds += delta
	else:
		_time_since_not_moving_seconds = 0
	if _time_since_not_moving_seconds > RESPAWN_BOT_AFTER_STUCK_FOR_SECONDS and is_instance_of(_brain, BotBrain):
		_time_since_not_moving_seconds = 0
		interface.respawn()
	
	#_track_state.get_track_region_manager().poll_coord(global_position)
	
	# debug =============================
	var debug_pos = global_position + Vector3(0, 3, 0)
	#DebugDraw2D.set_text("Velocity", "%0.2f" % linear_velocity.length())
	DebugDraw2D.set_text("FPS", Engine.get_frames_per_second())
	#if (show_debug_arrows):
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + linear_velocity, Color(0, 0, 1), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_centrifugal_force, Color(0, 1, 0), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_sliding_force, Color(1, 0, 0), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_sliding_force_compensated, Color(1, 0, 0.5), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_soft_clamp_speed_force, Color(1, 0, 1), 0.1)
		
	DebugDraw2D.set_text(interface.name + " client", global_position)
