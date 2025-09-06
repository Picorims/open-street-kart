# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PlayerSpawner extends Node3D

@export var racePath: RacePath

enum CountdownState {
	THREE = 3,
	TWO = 2,
	ONE = 1,
	GO = 0,
	IDLE = -1,
}

const CAR_SCENE: PackedScene = preload("res://prefabs/car_custom_physics_2.tscn")
const COUNTDOWN_DURATION: CountdownState = CountdownState.THREE
const CARS_COUNT = 16

var _inCountdown: bool = false
var _countDownState = 0
var _countdownElapsed: float = 0
var cars: Array[RigidBody3D] = []
var carRootNodes: Array[CarCustomPhysics2] = []

signal go

var TrackSpeedDict: Dictionary[TrackState.SpeedMode, float] = {
	TrackState.SpeedMode.CHILL: 15,
	TrackState.SpeedMode.CASUAL: 20,
	TrackState.SpeedMode.CHALLENGING: 25,
	TrackState.SpeedMode.CRAZY: 32
}
var OutOfBoundsSpeedDict: Dictionary[TrackState.SpeedMode, float] = {
	TrackState.SpeedMode.CHILL: 4,
	TrackState.SpeedMode.CASUAL: 6,
	TrackState.SpeedMode.CHALLENGING: 8,
	TrackState.SpeedMode.CRAZY: 10
}

func _ready() -> void:
	assert(racePath != null, "ERROR: racePath not configured on player spawner.")

func init(mode: TrackState.GameMode, speed: TrackState.SpeedMode):
	print("Initializing player spawner...")
	var count: int = 0
	if (mode == TrackState.GameMode.AGAINST_CLOCK):
		count = 1
	elif (mode == TrackState.GameMode.VERSUS):
		count = CARS_COUNT
	
	for i in range(count):
		var car: CarCustomPhysics2 = CAR_SCENE.instantiate()
		self.add_child(car)
		car.display_name = "p{0}".format([i+1])
		car.material = StandardMaterial3D.new()
		car.material.albedo_color = Color(randf(), randf(), randf())
		if (i == count-1):
			car.mode = CarCustomPhysics2.CarMode.USER
			car.display_name = "you"
			var cam: Camera3D = car.get_node("CarRigidBody/Camera3D")
			if (cam != null):
				cam.current = true
				car.show_debug_arrows = true
			else:
				push_error("ERROR: Could not set user as main camera focus.")
		else:
			car.mode = CarCustomPhysics2.CarMode.BOT
		car.path = racePath
		car.speed_multiplier = 1.0
		car.max_speed_meters_per_second = TrackSpeedDict.get(speed)
		car.max_speed_out_of_bounds_meters_per_second = OutOfBoundsSpeedDict.get(speed)
		car.basis = self.basis
		car.global_transform = self.global_transform
		car.global_position += self.basis.x * -i + self.basis.z * (i % 4) + self.basis.y * 5
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
		carRootNodes.append(car)
	print("Initializing player spawner done.")

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
