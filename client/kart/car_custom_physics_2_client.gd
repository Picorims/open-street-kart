# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


extends Node3D


var current_direction: Vector3 = Vector3(1, 0, 0)
@export var show_debug_arrows: bool = false
@export var interface: CarCustomPhysics2Client
@export var mode: CarCustomPhysics2Client.CarMode #FIXME shared enum?
@export var path: RacePath
var items_holder: Node3D = null

func is_in_speed_boost() -> bool:
	return false
	#return _now_seconds < _speed_boost_until_seconds

func _ready() -> void:
	assert(interface != null, "ERROR: interface not assigned.")	
	
func _process(_delta: float) -> void:
	interface.speed_boost_effects = is_in_speed_boost()
	
	# debug =============================
	#var debug_pos = global_position + Vector3(0, 3, 0)
	#DebugDraw2D.set_text("Velocity", "%0.2f" % linear_velocity.length())
	#if (show_debug_arrows):
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + linear_velocity, Color(0, 0, 1), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_centrifugal_force, Color(0, 1, 0), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_sliding_force, Color(1, 0, 0), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_sliding_force_compensated, Color(1, 0, 0.5), 0.1)
		#DebugDraw3D.draw_arrow(debug_pos, debug_pos + _debug_soft_clamp_speed_force, Color(1, 0, 1), 0.1)
		
	#DebugDraw2D.set_text(interface.name + " client", global_position)
