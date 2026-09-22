# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@icon("res://addons/at-icons/node/receiver.svg")
class_name MovingItemReceiver extends Node

var _physics_ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")

@export var smoothing_factor_pos := 0.5
@export var smoothing_factor_pos_for_estimated_vel := 0.8
@export var smoothing_factor_rot := 0.9
@export var smoothing_factor_estimated_vel := 0.9
@export var network_id: int = -1

@export var monitor := false:
	set(v):
		var monitor_name := "osk/moving item receiver %d" % network_id
		monitor = v
		if monitor and not Performance.has_custom_monitor(monitor_name):
			Performance.add_custom_monitor(monitor_name, _monitor_packets)
		elif Performance.has_custom_monitor(monitor_name):
			Performance.remove_custom_monitor(monitor_name)

var _parent: Node3D = null
var _active := false
var _server_pos := Vector3.ZERO
## units/s
var server_velocity = Vector3.ZERO
var _accumulated_velocity := Vector3.ZERO
var _server_rot := Vector3.ZERO
## radians/s
var _server_angular_vel := Vector3.ZERO
var _accumulated_angular_vel := Vector3.ZERO
var _local_current_pos := Vector3.ZERO
var _local_previous_pos := Vector3.ZERO
var estimated_local_velocity = Vector3.ZERO
var last_timestamp := 0

func _enter_tree() -> void:
	_parent = get_parent()
	_active = true

func _exit_tree() -> void:
	_parent = null
	_active = false

func link(client: ClientManager):
	client.get_rpc().c_on_moving_item_update.connect(func(nid: int, pos: Vector3, rot: Vector3, vel: Vector3, ang_vel: Vector3, time: int):
		if nid == network_id:
			if time < last_timestamp:
				return
			_server_pos = pos
			server_velocity = vel
			_accumulated_velocity = _vel_with_ang_vel_combined(vel, ang_vel / float(_physics_ticks))
			_server_rot = rot
			_server_angular_vel = ang_vel
			_accumulated_angular_vel = ang_vel
			last_timestamp = time

			if monitor:
				_packets_received_per_seconds += 1
				call_deferred("schedule_decrease_packets_received_per_seconds")
	)

func _vel_with_ang_vel_combined(vel: Vector3, ang_vel: Vector3) -> Vector3:
	if vel.length() < 0.01 or ang_vel.length() < 0.01:
		return vel
	var quaternion := Quaternion.from_euler(ang_vel)
	var new_vel := quaternion.normalized() * vel
	return new_vel

func _physics_process(_delta: float) -> void:
	# apply the velocity based on the physics tick rate,
	# assuming the server doesn't lag and get a physics rate drop.
	var target_pos := _server_pos
	var target_rot := _server_rot
	DebugDraw3D.draw_points([_local_current_pos], DebugDraw3D.POINT_TYPE_SPHERE, 0.25, Color.RED)
	DebugDraw3D.draw_points([_local_previous_pos], DebugDraw3D.POINT_TYPE_SPHERE, 0.25, Color.REBECCA_PURPLE)
	target_pos += _accumulated_velocity / float(_physics_ticks)
	target_rot += _accumulated_angular_vel / float(_physics_ticks)
	_accumulated_velocity += _vel_with_ang_vel_combined(server_velocity, _accumulated_angular_vel / float(_physics_ticks))
	_accumulated_angular_vel += _server_angular_vel
	
	var sf_pos := smoothing_factor_pos
	var sf_rot := smoothing_factor_pos
	_parent.global_position = Global.Math.ease(_parent.global_position, target_pos, sf_pos)
	_parent.global_rotation = Global.Math.ease(_parent.global_rotation, target_rot, sf_rot)
	_local_previous_pos = _local_current_pos
	_local_current_pos = Global.Math.ease(_local_current_pos, _parent.global_position, smoothing_factor_pos_for_estimated_vel)
	var estimated_vel = (_local_current_pos - _local_previous_pos).normalized()
	if estimated_vel.dot(server_velocity) < 0.5:
		estimated_vel = server_velocity
	estimated_vel = estimated_vel.normalized() * server_velocity.length()
	estimated_vel = (estimated_vel + server_velocity) / 2.0
	var sf_vel := smoothing_factor_estimated_vel
	estimated_local_velocity = Global.Math.ease(estimated_local_velocity, estimated_vel, sf_vel)


func schedule_decrease_packets_received_per_seconds():
	await get_tree().create_timer(1.0).timeout
	_packets_received_per_seconds -= 1


var _packets_received_per_seconds := 0
func _monitor_packets() -> int:
	return _packets_received_per_seconds
