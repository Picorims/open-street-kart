# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name WallOfWheels extends Path3D

const WHEEL_RADIUS = 0.6
const GAP_BETWEEN_WHEELS = 0.75
const VERTICAL_GAP = 0.01
const WHEEL_DEPTH = 0.4
const STACK_COUNT = 2

var _isDirty: bool = false
var _lastUpdateRequest: float = 0
const DELAY_AFTER_UPDATE_MS: float = 2_000

func _ready() -> void:
	if (self.curve_changed.is_connected(_on_curve_changed)):
		self.curve_changed.disconnect(_on_curve_changed)
	self.curve_changed.connect(_on_curve_changed)
	if (self.get_child_count() == 0): # do not override pre saved path
		_update_wall()
	
func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec()
	if (now - _lastUpdateRequest > DELAY_AFTER_UPDATE_MS && _isDirty):
		_isDirty = false
		_update_wall()
	
func _update_wall():
	for c in self.get_children():
		self.remove_child(c)
		c.queue_free()
	var pathLength: float = curve.get_baked_length()
	var step: float = WHEEL_RADIUS * 2 + GAP_BETWEEN_WHEELS
	var count: int = floor(pathLength / step)
	var offset: float = WHEEL_RADIUS
	for i in range(count):
		var curveDistance: float = offset + step * i
		var position: Vector3 = curve.sample_baked(curveDistance, true)
		_create_wheel_pillar(position, i)
		
func _create_wheel_pillar(pos: Vector3, index: int):
	for i in range(STACK_COUNT):
		var wheel: Wheel = Wheel.new()
		self.add_child(wheel)
		wheel.position = pos + Vector3(0, (WHEEL_DEPTH + VERTICAL_GAP) * i, 0)
		wheel.height = WHEEL_DEPTH
		wheel.radius = WHEEL_RADIUS
		if (index % 2 == 0):
			wheel.color = Color(1,1,1)
		else:
			wheel.color = Color(1,0.2,0.2)

func _on_curve_changed() -> void:
	_lastUpdateRequest = Time.get_ticks_msec() # must be first to not instant trigger!
	_isDirty = true
