# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@icon("res://addons/at-icons/node/receiver.svg")
class_name MovingItemReceiver extends Node

@export var smoothing_factor := 0.0
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
var current_velocity = Vector3.ZERO
var _last_timestamp := 0

func _enter_tree() -> void:
	_parent = get_parent()
	_active = true

func _exit_tree() -> void:
	_parent = null
	_active = false

func link(client: ClientManager):
	client.get_rpc().c_on_moving_item_update.connect(func(nid: int, pos: Vector3, rot: Vector3, vel: Vector3, _torque: Vector3, time: int):
		if nid == network_id:
			if time < _last_timestamp:
				return
			_parent.global_position = smoothing_factor * _parent.global_position + (1.0 - smoothing_factor) * pos
			_parent.global_rotation = rot
			current_velocity = vel
			_last_timestamp = time
			if monitor:
				_packets_received_per_seconds += 1
				call_deferred("schedule_decrease_packets_received_per_seconds")
	)

func schedule_decrease_packets_received_per_seconds():
	await get_tree().create_timer(1.0).timeout
	_packets_received_per_seconds -= 1


var _packets_received_per_seconds := 0
func _monitor_packets() -> int:
	return _packets_received_per_seconds
