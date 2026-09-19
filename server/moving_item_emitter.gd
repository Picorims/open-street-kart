# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@icon("res://addons/at-icons/node/emitter.svg")
class_name MovingItemEmitter extends Node

@export var server: ServerManager = null:
	set(v):
		server = v
		_network_id = server.claim_network_id()

@export var monitor := false:
	set(v):
		var monitor_name := "osk/moving item emitter %d" % _network_id
		monitor = v
		if monitor and not Performance.has_custom_monitor(monitor_name):
			Performance.add_custom_monitor(monitor_name, _monitor_packets)
		elif Performance.has_custom_monitor(monitor_name):
			Performance.remove_custom_monitor(monitor_name)

var _network_id: int = -1
var _active = false
var _parent: TrackableRigidBody3D = null

func get_network_id() -> int:
	return _network_id

func _enter_tree() -> void:
	_parent = get_parent()
	assert(is_instance_of(_parent, RigidBody3D), "MovingItemEmitter can only be a child of (the tracked) RigidBody3D.")
	_active = true
	
func _exit_tree() -> void:
	_parent = null
	_active = false

func _physics_process(_delta: float) -> void:
	if _network_id == -1:
		return
	if _active:
		var pos := _parent.global_position
		var rot := _parent.global_rotation
		var vel := _parent.current_velocity
		var torque := _parent.current_torque
		var time := Time.get_ticks_msec()
		server.get_rpc().s2c_send_moving_item_data(_network_id, pos, rot, vel, torque, time)
		_packets_sent_per_seconds += 1
		call_deferred("schedule_decrease_packets_sent_per_seconds")

func schedule_decrease_packets_sent_per_seconds():
	await get_tree().create_timer(1.0).timeout
	_packets_sent_per_seconds -= 1


var _packets_sent_per_seconds := 0
func _monitor_packets() -> int:
	return _packets_sent_per_seconds
