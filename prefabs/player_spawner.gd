# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PlayerSpawner extends Node3D

@export var race_path: RacePath

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

var _in_countdown: bool = false
var _countdown_state = 0
var _countdown_elapsed: float = 0
var cars: Array[RigidBody3D] = []
var car_root_nodes: Array[CarCustomPhysics2] = []
var _car_root_node_map: Dictionary[String, CarCustomPhysics2] = {}

signal go

var TrackSpeedDict: Dictionary[TrackState.SpeedMode, float] = {
	TrackState.SpeedMode.CHILL: 15,
	TrackState.SpeedMode.CASUAL: 20,
	TrackState.SpeedMode.CHALLENGING: 25,
	TrackState.SpeedMode.CRAZY: 32,
}
var OutOfBoundsSpeedDict: Dictionary[TrackState.SpeedMode, float] = {
	TrackState.SpeedMode.CHILL: 4,
	TrackState.SpeedMode.CASUAL: 6,
	TrackState.SpeedMode.CHALLENGING: 8,
	TrackState.SpeedMode.CRAZY: 10,
}

func _ready() -> void:
	assert(race_path != null, "ERROR: race_path not configured on player spawner.")

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
		car.display_name = "p{0}".format([i + 1])
		car.material = StandardMaterial3D.new()
		car.material.albedo_color = Color(randf(), randf(), randf())
		if (i == count - 1):
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
		car.path = race_path
		car.speed_multiplier = 1.0
		car.max_speed_meters_per_second = TrackSpeedDict.get(speed)
		car.max_speed_out_of_bounds_meters_per_second = OutOfBoundsSpeedDict.get(speed)
		car.basis = self.basis
		car.global_transform = self.global_transform
		car.global_position += self.basis.x * -i + self.basis.z * (i % 4) + self.basis.y * 5
		var rigid_body: RigidBody3D = car.get_node("CarRigidBody")
		rigid_body.freeze = true
		
		var snap_ray_cast = SnapToGroundRayCast3D.new()
		self.add_child(snap_ray_cast)
		snap_ray_cast.align_to_normal = true
		snap_ray_cast.offset = -0.5
		snap_ray_cast.target_position = Vector3(0, -1000, 0)
		snap_ray_cast.target = car
		snap_ray_cast.force_raycast_update()
		
		cars.append(rigid_body)
		car_root_nodes.append(car)
		_car_root_node_map.set(car.name, car)
	print("Initializing player spawner done.")

func _process(delta: float) -> void:
	if (_in_countdown):
		_countdown_elapsed += delta
		
		if (_countdown_state == CountdownState.IDLE): # initialize
			print("3...")
			_countdown_state = CountdownState.THREE
		elif (_countdown_state == CountdownState.THREE and _countdown_elapsed > 1):
			print("2...")
			_countdown_state = CountdownState.TWO
		elif (_countdown_state == CountdownState.TWO and _countdown_elapsed > 2):
			print("1...")
			_countdown_state = CountdownState.ONE
		elif (_countdown_state == CountdownState.ONE and _countdown_elapsed > 3):
			print("GO!")
			_countdown_state = CountdownState.GO
			go.emit()
		
		if (_countdown_elapsed > COUNTDOWN_DURATION):
			for c in cars:
				c.freeze = false
			_in_countdown = false
			_countdown_state = CountdownState.IDLE

func countdown():
	_countdown_elapsed = 0
	_countdown_state = CountdownState.IDLE
	_in_countdown = true

func get_car_by_id(id: String) -> CarCustomPhysics2:
	return _car_root_node_map.get(id)
