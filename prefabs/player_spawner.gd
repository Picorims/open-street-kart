# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PlayerSpawner extends Node3D

enum CountdownState {
	THREE = 3,
	TWO = 2,
	ONE = 1,
	GO = 0,
	IDLE = -1,
}

const CAR_SCENE: PackedScene = preload("res://prefabs/car_custom_physics_2.tscn")
const COUNTDOWN_DURATION: CountdownState = CountdownState.THREE

var _inCountdown: bool = false
var _countDownState = 0
var _countdownElapsed: float = 0
var cars: Array[RigidBody3D] = []

signal go

func _ready() -> void:
	var car: Node3D = CAR_SCENE.instantiate()
	self.add_child(car)
	car.speedMultiplier = 1.5
	car.basis = self.basis
	car.global_transform = self.global_transform
	var rigidBody: RigidBody3D = car.get_node("CarRigidBody")
	rigidBody.freeze = true
	
	var snapRayCast = SnapToGroundRayCast3D.new()
	self.add_child(snapRayCast)
	snapRayCast.alignToNormal = true
	snapRayCast.offset = -0.5
	snapRayCast.target_position = Vector3(0, -1000, 0)
	snapRayCast.target = car
	snapRayCast.force_raycast_update()
	
	cars.append(rigidBody)


func _process(delta: float) -> void:
	if (_inCountdown):
		_countdownElapsed += delta
		
		if (_countDownState == CountdownState.IDLE): # initialize
			print("3...")
			_countDownState = CountdownState.THREE
		elif (_countDownState == CountdownState.THREE && _countdownElapsed > 1):
			print("2...")
			_countDownState = CountdownState.TWO
		elif (_countDownState == CountdownState.TWO && _countdownElapsed > 2):
			print("1...")
			_countDownState = CountdownState.ONE
		elif (_countDownState == CountdownState.ONE && _countdownElapsed > 3):
			print("GO!")
			_countDownState = CountdownState.GO
			go.emit()
		
		if (_countdownElapsed > COUNTDOWN_DURATION):
			for c in cars:
				c.freeze = false
			_inCountdown = false
			_countDownState = CountdownState.IDLE

func countdown():
	_countdownElapsed = 0
	_countDownState = CountdownState.IDLE
	_inCountdown = true
