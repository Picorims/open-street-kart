# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PlayerSpawner extends Node3D

signal spawned_kart(kart: CarCustomPhysics2Client)

const CAR_SCENE_SERVER: PackedScene = preload("res://server/kart/car_custom_physics_2_server.tscn")
const CAR_SCENE_CLIENT: PackedScene = preload("res://client/kart/car_custom_physics_2_client.tscn")
const KART_SYNC: PackedScene = preload("res://common/kart/kart_sync.tscn")

@export var race_path: RacePath
@export var items_holder: Node3D
@onready var _multiplayer_spawner: MultiplayerSpawner = $KartSyncMultiplayerSpawner
@onready var _karts_container: Node3D = $KartsContainer

var cars: Array[RigidBody3D] = []
var car_root_nodes: Array[CarCustomPhysics2Server] = []
var _car_root_node_map: Dictionary[String, CarCustomPhysics2Server] = {}
var track: Track


func _ready() -> void:
	assert(race_path != null, "ERROR: race_path not configured on player spawner.")
	assert(items_holder != null, "ERROR: items_holder not configured on player spawner.")

func init(mode: TrackStateModel.GameMode, speed: TrackStateModel.SpeedMode, cars_count: int):
	print("Initializing player spawner...")
	assert(track != null, "Missing track reference.")
	if track.instance == Track.TrackInstance.SERVER:
		_init_server(mode, speed, cars_count)
	elif track.instance == Track.TrackInstance.CLIENT:
		_init_client()
	else:
		push_error("Track mode undefined, cannot initialize player spawner.")
	

func _init_server(mode, speed, cars_count):
	var count: int = 0
	if (mode == TrackStateModel.GameMode.AGAINST_CLOCK):
		count = 1
	elif (mode == TrackStateModel.GameMode.VERSUS):
		count = cars_count
	
	_multiplayer_spawner.spawn_limit = count
	
	for i in range(count):
		var car: CarCustomPhysics2Server = CAR_SCENE_SERVER.instantiate()
		var kart_sync: KartSync = KART_SYNC.instantiate()
		car.kart_sync = kart_sync
		
		_karts_container.add_child(car)
		
		car.items_holder = items_holder
		car.display_name = "p{0}".format([i + 1])
		if (i == count - 1):
			car.mode = CarCustomPhysics2Server.CarMode.USER
			car.display_name = "you"
			#car.show_debug_arrows = true
		else:
			car.mode = CarCustomPhysics2Server.CarMode.BOT
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
		
		kart_sync.display_name = car.display_name
		kart_sync.name = "%s_pos_sync" % car.display_name
		kart_sync.kart_color = Color(randf(), randf(), randf())
		
		_multiplayer_spawner.add_child(kart_sync)
	print("Initializing player spawner done.")
	
func _init_client():
	_multiplayer_spawner.spawned.connect(func(kart_sync: KartSync):
		var kart: CarCustomPhysics2Client = CAR_SCENE_CLIENT.instantiate()
		kart.display_name = kart_sync.display_name
		kart.name = kart_sync.display_name
		kart.material = StandardMaterial3D.new()
		kart.material.albedo_color = Color(randf(), randf(), randf())

		_karts_container.add_child(kart)
		#kart_sync.remote_path = "../KartsContainer/%s" % kart.name
		kart_sync.remote_path = kart.get_path()
		kart.kart_sync = kart_sync
		spawned_kart.emit(kart)
		print("Client: spawned %s for %s" % [kart.name, kart_sync.name])
		print("kart is in ", kart.get_path())
		print("kart sync is in ", kart_sync.get_path())
		print("kart sync controls ", kart_sync.remote_path)
	)
	_multiplayer_spawner.despawned.connect(func(kart_sync: KartSync):
		var kart: Node3D = _karts_container.find_child(kart_sync.display_name)
		if kart != null:
			_karts_container.remove_child(kart)
			kart.queue_free()
	)

func get_car_by_id(id: String) -> CarCustomPhysics2Server:
	return _car_root_node_map.get(id)

func unfreeze_cars():
	for c in cars:
		c.freeze = false
