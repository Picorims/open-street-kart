# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name MapDataLoader extends Node3D

@export var topoDataPath: String
@export var osmDataPath: String
@export var boundariesDataPath: String
#@export var latitudeScale = 111320
#@export var longitudeScale = 111320
@export var latitudeOrigin: String = "0.0"
@export var longitudeOrigin: String = "0.0"
@export var elevationOrigin: String = "0.0"
# icons: Godot EditorIcons; https://godot-editor-icons.github.io/
@export_tool_button("Reload surface", "ImageTexture3D") var reload_surface_action = Callable(self, "_reload_surface_action")
@export_tool_button("Reload OSM Data", "Path3D") var reload_osm_action = Callable(self, "_reload_osm_action")
@export_tool_button("Reload Boundaries Data", "Area3D") var reload_boundaries_action = Callable(self, "_reload_boundaries_action")
@export var floorMaterial: Material

var _origin: Vector3
var _scaleTransform: Vector3

func get_scale_transform(lat) -> Vector3:
	# see: https://stackoverflow.com/questions/639695/how-to-convert-latitude-or-longitude-to-meters
	
	# =====================================================================
	# From Ben on StackOverflow (https://stackoverflow.com/a/39540339):
	# Given you're looking for a simple formula, this is probably the simplest way
	# to do it, assuming that the Earth is a sphere with a circumference of 40075 km.
	#
	# Length in km of 1° of latitude = always 111.32 km
	#
	# Length in km of 1° of longitude = 40075 km * cos( latitude ) / 360
	# =====================================================================
	
	# Elevation is not scaled. Using meters.
	return Vector3(40075000 * cos(lat) / 360, 1, 111320)

func _ready() -> void:
	_origin = Vector3(float(latitudeOrigin), float(elevationOrigin), float(longitudeOrigin))
	#_scaleTransform = Vector3(latitudeScale, 1, longitudeScale)
	print("world origin: ", _origin)

func get_origin() -> Vector3:
	return _origin
	
func get_origin_meters() -> Vector3:
	_scaleTransform = get_scale_transform(_origin.x)
	return _origin * _scaleTransform

func lat_alt_lon_to_world_global_pos(latAltLon: Vector3, verbose = false) -> Vector3:
	
	_scaleTransform = get_scale_transform(latAltLon.x)
	if verbose:
		print("doing (", latAltLon, " - ", _origin, ') * ', _scaleTransform)
	return (latAltLon - _origin) * _scaleTransform

func _reload_surface_action():
	print("=== reloading surface elevation ===")
	$Surface.reload_action(floorMaterial)
	print ("=== reloading surface done ===")

func _reload_osm_action():
	print("=== reloading roads ===")
	$OSMDataGenerator.reload_action()
	print ("=== reloading roads done ===")
	
func _reload_boundaries_action():
	print("=== reloading boundaries ===")
	$BoundariesGenerator.reload_action()
	print ("=== reloading boundaries done ===")
