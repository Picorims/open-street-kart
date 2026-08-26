# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PlayerSpawner extends Node3D

const CAR_SCENE: PackedScene = preload("res://prefabs/car_custom_physics_2.tscn")

@export var race_path: RacePath
@export var items_holder: Node3D

var cars: Array[RigidBody3D] = []
var car_root_nodes: Array[CarCustomPhysics2] = []
var _car_root_node_map: Dictionary[String, CarCustomPhysics2] = {}



func _ready() -> void:
	assert(race_path != null, "ERROR: race_path not configured on player spawner.")
	assert(items_holder != null, "ERROR: items_holder not configured on player spawner.")

func init(mode: TrackStateModel.GameMode, speed: TrackStateModel.SpeedMode, cars_count: int):
	print("Initializing player spawner...")
	var count: int = 0
	if (mode == TrackStateModel.GameMode.AGAINST_CLOCK):
		count = 1
	elif (mode == TrackStateModel.GameMode.VERSUS):
		count = cars_count
	
	for i in range(count):
		var car: CarCustomPhysics2 = CAR_SCENE.instantiate()
		self.add_child(car)
		car.items_holder = items_holder
		car.display_name = "p{0}".format([i + 1])
		car.material = StandardMaterial3D.new()
		car.material.albedo_color = Color(randf(), randf(), randf())
		if (i == count - 1):
			car.mode = CarCustomPhysics2.CarMode.USER
			car.display_name = "you"
			#car.show_debug_arrows = true
		else:
			car.mode = CarCustomPhysics2.CarMode.BOT
		car.path = race_path
		car.speed_multiplier = 1.0
		assert(TrackStateModel.TrackSpeedDict.has(speed), "mising speed for mode %s" % speed)
		assert(TrackStateModel.OutOfBoundsSpeedDict.has(speed), "mising OOB speed for mode %s" % speed)
		car.max_speed_meters_per_second = TrackStateModel.TrackSpeedDict.get(speed)
		car.max_speed_out_of_bounds_meters_per_second = TrackStateModel.OutOfBoundsSpeedDict.get(speed)
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

func get_car_by_id(id: String) -> CarCustomPhysics2:
	return _car_root_node_map.get(id)

func unfreeze_cars():
	for c in cars:
		c.freeze = false
