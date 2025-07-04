# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name MapDataLoader extends Node3D

@export var topoDataPath: String
@export var osmDataPath: String
@export var latitudeScale = 111320
@export var longitudeScale = 111320
@export var latitudeOrigin: String = "0.0"
@export var longitudeOrigin: String = "0.0"
@export var elevationOrigin: String = "0.0"
# icons: Godot EditorIcons; https://godot-editor-icons.github.io/
@export_tool_button("Reload surface", "ImageTexture3D") var reload_surface_action = Callable(self, "_reload_surface_action")
@export_tool_button("Reload OSM Data", "Path3D") var reload_osm_action = Callable(self, "_reload_osm_action")
@export var floorMaterial: Material

var _origin: Vector3
func _ready() -> void:
	_origin = Vector3(float(latitudeOrigin), float(elevationOrigin), float(longitudeOrigin))
	print("world origin: ", _origin)

func get_origin() -> Vector3:
	return _origin

func lat_alt_lon_to_world_global_pos(latAltLon: Vector3, verbose = false):
	var scaleTransform: Vector3 = Vector3(latitudeScale, 1, longitudeScale)
	if verbose:
		print("doing (", latAltLon, " - ", _origin, ') * ', scaleTransform)
	return (latAltLon - _origin) * scaleTransform

func _reload_surface_action():
	print("=== reloading surface elevation ===")
	$Surface.reload_action(floorMaterial)
	print ("=== reloading surface done ===")

func _reload_osm_action():
	print("=== reloading roads ===")
	$OSMDataGenerator.reload_action()
	print ("=== reloading roads done ===")
