# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
## `RigidBody3D` with finer freeze control for performance improvement.
## Has exclusivity over Physics3D Layer 6
class_name FreezeManagedRigidBody3D extends RigidBody3D

signal freezeChanged(freeze: bool)
## emitted after timeout ellapsed since unfrozen, if effectively still unfrozen.
signal timeout

## Use this instead of `freeze` for the signal and other logic to work.
@export var managedFreeze: bool:
	get:
		return freeze
	set(v):
		managedFreeze = v
		freeze = v
		freezeChanged.emit(v)
		if (!freeze):
			_lastUnfreezeMs = Time.get_ticks_msec()

## Timeout before the timeout signal is emitted.
@export var timeoutMs: float = 15_000
## Minimum timeout before freezing can happen again.
@export var minTimeoutMs: float = 1_000

## Together with the `freezeNotMovingTreshold`, freeze if the linear velocity
## is below this value
@export var freezeIfNotMoving: bool = true

## If `freezeIfNotMoving` and linear velocity is below this value, freeze.
@export var freezeNotMovingTreshold: float = 0.05:
	set(v):
		freezeNotMovingTreshold = v
		_freezeNotMovingTresholdSquared = v*v

var _lastUnfreezeMs: float = 0
var _freezeNotMovingTresholdSquared: float = freezeNotMovingTreshold * freezeNotMovingTreshold

func _ready() -> void:
	
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	managedFreeze = true

var _ellpased: float = 0
func _physics_process(delta: float) -> void:
	if (!get_collision_layer_value(6)):
		set_collision_layer_value(6, true)
	
	# avoid running too often
	_ellpased += delta
	if (_ellpased < 0.05):
		return
	else:
		_ellpased = 0
	
	var nowMs: float = Time.get_ticks_msec()
	var unfrozenEllapsed: float = nowMs - _lastUnfreezeMs
	if (unfrozenEllapsed > timeoutMs && !freeze):
		timeout.emit()
	if (linear_velocity.length_squared() < _freezeNotMovingTresholdSquared && !freeze) && unfrozenEllapsed > minTimeoutMs:
		managedFreeze = true
