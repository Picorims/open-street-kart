# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PlayerSpawner extends Node3D

const CAR_SCENE: PackedScene = preload("res://prefabs/car_custom_physics_2.tscn")
const COUNTDOWN_DURATION: float = 3

var _inCountdown: bool = false
var _countDownState = 0
var _countdownEllapsed: float = 0
var cars: Array[RigidBody3D] = []

func _ready() -> void:
	var car: Node3D = CAR_SCENE.instantiate()
	self.add_child(car)
	car.basis = self.basis
	#car.global_position = self.global_position
	#car.transform = self.transform
	var rigidBody: RigidBody3D = car.get_node("CarRigidBody")
	rigidBody.freeze = true
	
	var snapRayCast = SnapToGroundRayCast3D.new()
	self.add_child(snapRayCast)
	#snapRayCast.global_position = self.global_position + Vector3(0, -1, 0)
	snapRayCast.alignToNormal = true
	snapRayCast.offset = -0.5
	snapRayCast.target_position = Vector3(0, -1000, 0)
	snapRayCast.target = car
	snapRayCast.force_raycast_update()
	
	cars.append(rigidBody)
	
	# temporary, until full race load is implemented
	countdown()

func _process(delta: float) -> void:
	if (_inCountdown):
		_countdownEllapsed += delta
		
		if (_countDownState == 0):
			print("3...")
			_countDownState = 3
		elif (_countDownState == 3 && _countdownEllapsed > 1):
			print("2...")
			_countDownState = 2
		elif (_countDownState == 2 && _countdownEllapsed > 2):
			print("1...")
			_countDownState = 1
		elif (_countDownState == 1 && _countdownEllapsed > 3):
			print("GO!")
			_countDownState = 0
		
		if (_countdownEllapsed > COUNTDOWN_DURATION):
			for c in cars:
				c.freeze = false
			_inCountdown = false

func countdown():
	_countdownEllapsed = 0
	_countDownState = 0
	_inCountdown = true
