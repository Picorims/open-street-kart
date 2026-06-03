# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## System loading and unloading nodes based on their position,
## and position polling from other nodes (defining which regions are loaded)
##
## **Note:** May not behave correctly for objects with a bbox larger
## than the chunk size.
class_name TrackRegionManager extends Node

## manages a list of targets, associated to a chunk (coordinates).
class Region:
	var _parent: TrackRegionManager
	var _targets: Array[Node3D]
	var _enabled_timestamp: float
	var _enabled: bool = false
	var _pos: Vector2
	
	func is_enabled() -> bool:
		return _enabled
	
	## parent is the time reference, now is requested using get_now().
	func _init(parent: TrackRegionManager, pos: Vector2) -> void:
		_parent = parent
		_pos = pos
	
	## Enable all targets processes.
	func enable() -> void:
		_enabled_timestamp = _parent.get_now()
		for t in _targets:
			_enable_node(t)
		_enabled = true
		_parent.active_regions.append(self)
		print("enabled ", _targets.size(), " nodes in chunk: ", _pos)
	
	## Disable all targets processes.
	func disable() -> void:
		_enabled = false
		for t in _targets:
			_disable_node(t)
		print("disabled ", _targets.size(), " nodes in chunk: ", _pos)
	
	## Get timestamp of last call to enable() or poll().
	func last_enabled_timestamp() -> float:
		return _enabled_timestamp
	
	## Add a target to monitor by this region.
	func register(node: Node3D):
		_targets.append(node)
		if _enabled:
			_enable_node(node)
		else:
			_disable_node(node)
	
	## Reset the region timestamp to maintain it active, or
	## enable if not active
	func poll_or_enable() -> void:
		if not _enabled:
			enable()
		else:
			_enabled_timestamp = _parent.get_now()
	
	func _disable_node(node: Node3D) -> void:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		# Shall this break, other options can be considered:
		# see: https://forum.godotengine.org/t/how-to-disable-enable-a-node/22387/2
	
	func _enable_node(node: Node3D) -> void:
		node.process_mode = Node.PROCESS_MODE_INHERIT
		# Shall this break, other options can be considered:
		# see: https://forum.godotengine.org/t/how-to-disable-enable-a-node/22387/2
		
	
const CHUNK_SIZE = 64
const SLEEP_AFTER_SECONDS = 5

var active_regions: Array[Region] = []
var _regions: Dictionary[Vector2, Region] = {}
var _now: float = 0
func get_now() -> float:
	return _now

func _init() -> void:
	Performance.add_custom_monitor("game/enabled_regions", func(): return active_regions.size())

func pos_to_chunk(p: Vector3) -> Vector2:
	return floor(Vector2(p.x, p.z) / CHUNK_SIZE)

func register_node(node: Node3D) -> void:
	var chunk: Vector2 = pos_to_chunk(node.global_position)
	if not _regions.has(chunk):
		_regions.set(chunk, Region.new(self, chunk))
	_regions.get(chunk).register(node)

func poll_coord(global_pos: Vector3) -> void:
	var chunk: Vector2 = pos_to_chunk(global_pos)
	for i in range(-1, 2):
		for j in range(-1, 2):
			var area_chunk: Vector2 = chunk + Vector2(i,j)
			if _regions.has(area_chunk):
				var region: Region = _regions.get(area_chunk)
				region.poll_or_enable()


func tick(delta: float) -> void:
	_now += delta
	for i in range(active_regions.size()-1, -1, -1):
		var r: Region = active_regions[i]
		if _now > r.last_enabled_timestamp() + SLEEP_AFTER_SECONDS:
			r.disable()
			active_regions.erase(r)
