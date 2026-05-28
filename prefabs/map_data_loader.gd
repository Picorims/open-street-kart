# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
class_name MapDataLoader extends Node3D

@export var track: Track
@export var terrain: Terrain3D
@export var terrain_connector: RoadTerrain3DConnector
@export var topo_data_path: String
@export var osm_data_path: String
@export var boundaries_data_path: String
#@export var latitudeScale = 111320
#@export var longitudeScale = 111320
@export var latitude_origin: String = "0.0"
@export var longitude_origin: String = "0.0"
@export var elevation_origin: String = "0.0"
## heightmap width times scaling factor times meters per pixel (resolution)
@export var width_meters: int = 1000
## heightmap height times scaling factor times meters per pixel (resolution)
@export var length_meters: int = 1000
# icons: Godot EditorIcons; https://godot-editor-icons.github.io/
@export_tool_button("Reload surface", "ImageTexture3D") var reload_surface_action = Callable(self, "_reload_surface_action")
@export_tool_button("Reload Boundaries Data", "Area3D") var reload_boundaries_action = Callable(self, "_reload_boundaries_action")
@export_tool_button("Reload OSM Roads", "Path3D") var reload_osm_roads_action = Callable(self, "_reload_osm_roads_action")
# ROAD LINKING BROKEN
#@export_tool_button("Link Roads", "LinkButton") var link_roads_action = Callable(self, "_link_roads_action")
@export_tool_button("Reload OSM Buildings", "Path3D") var reload_osm_buildings_action = Callable(self, "_reload_osm_buildings_action")
@export_tool_button("Reload OSM Amenities", "Path3D") var reload_osm_amenities_action = Callable(self, "_reload_osm_amenities_action")
@export_tool_button("Apply manual OSM mutations script", "Script") var apply_osm_mutations_action = Callable(self, "_apply_osm_mutations_action")
@export var floor_material: Material

var _origin: Vector3
var _scale_transform: Vector3

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
	_origin = Vector3(float(latitude_origin), 0, float(longitude_origin))
	#_scale_transform = Vector3(latitudeScale, 1, longitudeScale)
	print("world origin: ", _origin)

#func _process(delta: float) -> void:
	# for some reason the collision layer changes are not saved. So we force it here.
	#if proceduralDataHolder:
		#var node: StaticBody3D = self.get_parent_node_3d().get_node("ProceduralDataHolder/ElevationStaticBody")
		#if node && node.get_collision_layer_value(2) == false:
			#node.set_collision_layer_value(2, true) # also in osm_data_generator.gd

func get_origin() -> Vector3:
	return _origin
	
func get_origin_meters() -> Vector3:
	_scale_transform = get_scale_transform(_origin.x)
	return _origin * _scale_transform

func lat_alt_lon_to_world_global_pos(lat_alt_lon: Vector3, verbose = false) -> Vector3:
	_scale_transform = get_scale_transform(lat_alt_lon.x)
	if verbose:
		print("doing (", lat_alt_lon, " - ", _origin, ') * ', _scale_transform)
	return (lat_alt_lon - _origin) * _scale_transform

func _get_root_of_current_scene(ok_callback: Callable) -> void:
	#var root_node: Node3D = get_tree().edited_scene_root.get_node("%ProceduralDataHolder")
	var root_node: Node3D = %ProceduralDataHolder
	if root_node == null:
		print("Missing %ProceduralDataHolder.")
	else:
		#print("Using %ProceduralDataHolder of ", get_tree().edited_scene_root.name)
		ok_callback.call(root_node)
	

func _reload_surface_action():
	_get_root_of_current_scene(func(root_node: Node3D):
		print("=== reloading surface elevation ===")
		$Surface.reload_action(floor_material, root_node)
		print("=== reloading surface done (DO NOT FORGET TO SAVE!!!) ===")
	)

func _reload_osm_roads_action():
	_reload_osm_action(OSMDataGenerator.ReloadKind.ROADS)
func _reload_osm_buildings_action():
	_reload_osm_action(OSMDataGenerator.ReloadKind.BUILDINGS)
func _reload_osm_amenities_action():
	_reload_osm_action(OSMDataGenerator.ReloadKind.AMENITIES)

func _reload_osm_action(kind: OSMDataGenerator.ReloadKind):
	_get_root_of_current_scene(func(root_node: Node3D):
		print("=== reloading roads ===")
		$OSMDataGenerator.reload_action(root_node, kind)
		print("=== reloading roads done (DO NOT FORGET TO SAVE!!!) ===")
	)

func _reload_boundaries_action():
	_get_root_of_current_scene(func(root_node: Node3D):
		print("=== reloading boundaries ===")
		$BoundariesGenerator.reload_action(root_node)
		print("=== reloading boundaries done (DO NOT FORGET TO SAVE!!!) ===")
	)

func _apply_osm_mutations_action():
	assert(track != null, "missing track reference.")
	_get_root_of_current_scene(func(root_node: Node3D):
		print("=== applying manual OSM mutations script ===")
		$OSMDataGenerator.apply_osm_mutations_action(root_node)
		print("=== applying manual OSM mutations script done (DO NOT FORGET TO SAVE!!!) ===")
	)

func _link_roads_action():
	var linker = RoadLinker.new()
	_get_root_of_current_scene(func(root_node: Node3D):
		root_node.add_child(linker)
		linker.linked.connect(func(): linker.queue_free())
		var road_manager: RoadManager = root_node.get_node("OSMData/Roads").get_child(0)
		linker.link_roads(road_manager, self)
	)

func persist_in_current_scene(node: Node3D) -> void:
	node.owner = get_tree().edited_scene_root
