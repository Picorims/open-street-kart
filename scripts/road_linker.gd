# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name RoadLinker extends Node3D

signal linked
const T_INTERSECT_SHIFT_DISTANCE_FACTOR: float = 2
const RP_NEXT := RoadPoint.PointInit.NEXT
const RP_PRIOR := RoadPoint.PointInit.PRIOR

class RoadLink:
	var nodes: Array[Node3D] = []
	func _init(a: Node3D, b: Node3D) -> void:
		nodes = [a,b]
	func equals(other: RoadLink) -> bool: # array order doesn't matter
		if other == self:
			return true
		if other.nodes[0] != self.nodes[0] and other.nodes[1] != self.nodes[0]: 
			return false
		if other.nodes[0] != self.nodes[1] and other.nodes[1] != self.nodes[1]: 
			return false
		return true
	
	func linked(other: RoadLink):
		if other == self:
			return false
		if other.nodes[0] == self.nodes[0] or other.nodes[1] == self.nodes[0]: 
			return true
		if other.nodes[0] == self.nodes[1] and other.nodes[1] == self.nodes[1]: 
			return true
		return false


var _distances: Dictionary[String, float]
var _links: Array[RoadLink]
## Array[Array[Node3D]]
var _groups: Array[Array]
var _can_link := false
var _attached_pairs := 0
var _t_intersections := 0
var _intersections := 0
var MIN_TICK_SLEEP_LINKING_S := 0.2
var _loader: MapDataLoader

func link_roads(road_manager: RoadManager, loader: MapDataLoader):
	print("Identifying road nodes to link...")
	_loader = loader
	_distances = {}
	_links = []
	_groups = []
	_attached_pairs = 0
	_t_intersections = 0
	_intersections = 0
	for container: Node3D in road_manager.get_children():
		for container2: Node3D in road_manager.get_children():
			if container == container2:
				continue
			
			for point: Node3D in container.get_children():
				for point2: Node3D in container2.get_children():
					var name_array: Array[String] = [point.name, point2.name]
					name_array.sort()
					var key: String = "%s-%s" % name_array
					var distance := 0.0
					if _distances.has(key):
						distance = _distances.get(key)
					else:
						distance = point.global_position.distance_to(point2.global_position)
						_distances.set(key, distance)
					if distance < 0.5:
						var link := RoadLink.new(point, point2)
						if _links.find_custom(func(v) -> bool: return link.equals(v)) == -1:
							_links.append(link)
	
	print("Identifying groups...")
	for link in _links:
		var n0 := link.nodes[0]
		var n1 := link.nodes[1]
		var found_existing_link := false
		for group in _groups:
			if group.has(n0):
				found_existing_link = true
				if not group.has(n1):
					group.append(n1)
				break
			if group.has(n1):
				found_existing_link = true
				if not group.has(n0):
					group.append(n0)
				break
		if not found_existing_link:
			_groups.append([n0, n1])

	print("Identified groups:")
	print(_groups)
	
	print("Pre-computing done. Launching linking...")
	_can_link = true

func _xor(a: bool, b: bool):
	return (a and not b) or (not a and b)

var _ellapsed := 0.0
func _physics_process(delta: float) -> void:
	if not _can_link:
		return
	if _groups.size() == 0:
		print("Linking done.")
		print("attached pairs: ", _attached_pairs)
		print("T intersections: ", _t_intersections)
		print("intersections: ", _intersections)
		linked.emit()
		_can_link = false
		return
	
	_ellapsed += delta
	if _ellapsed >= MIN_TICK_SLEEP_LINKING_S:
		_ellapsed = 0
		var group: Array = _groups.pop_back()
		
		if group == null:
			return
		
		if group.size() == 2:
			print("Trying connection (link or T intersection): ", group)
			var n0: RoadPoint = group[0]
			var n1: RoadPoint = group[1]
			var t_intersect := false # edge case: link to middle of other road
			# are both edges?
			if n0.is_next_connected() and n0.is_prior_connected() and _xor(n1.is_prior_connected(), n1.is_next_connected()):
				t_intersect = true
			if n1.is_next_connected() and n1.is_prior_connected() and _xor(n0.is_prior_connected(), n0.is_next_connected()):
				t_intersect = true
			print("T intersection: ", t_intersect)
			if not t_intersect:
				print("Trying pair-connection: ", group)
				_connect_rp_cross_container(n0, n1)
				_attached_pairs += 1
			else:
				print("Trying T-intersection: ", group)
				# TODO
				pass
				_t_intersections += 1
				# T intersection
				#var continuous_p: RoadPoint
				#var edge_p: RoadPoint
				#if n0.get_prior_road_node() != null and n0.get_next_road_node() != null:
					#continuous_p = n0
					#edge_p = n1
				#else:
					#continuous_p = n1
					#edge_p = n0
				#
				## first, move the edge out of the continuous road
				#var move_axis: Vector3 = edge_p.transform.basis.x
				#if n0.get_next_road_node() != null:
					#move_axis *= -1
				#var continuous_size: float = continuous_p.lane_width * continuous_p.lanes.size()
				#continuous_size += continuous_p.shoulder_width_l + continuous_p.shoulder_width_r
				#continuous_size += 2 * continuous_p.gutter_profile.length() # approximate, ignore projection
				#var half_size := continuous_size / 2.0
				#var offset_distance := half_size * T_INTERSECT_SHIFT_DISTANCE_FACTOR
				#edge_p.position += move_axis * offset_distance
				#
				## second, split the continuous point into two side points
				#continuous_p.disconnect_roadpoint(RoadPoint.PointInit.NEXT, RoadPoint.PointInit.PRIOR)
				#continuous_p.disconnect_roadpoint(RoadPoint.PointInit.PRIOR, RoadPoint.PointInit.NEXT)
				#var next_p = RoadPoint.new()
				#var prior_p = RoadPoint.new()
				#var next_p_sibling = continuous_p.get_next_road_node()
				#var prior_p_sibling = continuous_p.get_prior_road_node()
				#next_p.copy_settings_from(continuous_p, false)
				#prior_p.copy_settings_from(continuous_p, false)
				#var continuous_axis = continuous_p.basis.x
				#next_p.position = continuous_p.position - continuous_axis * T_INTERSECT_SHIFT_DISTANCE_FACTOR
				#prior_p.position = continuous_p.position + continuous_axis * T_INTERSECT_SHIFT_DISTANCE_FACTOR
				#next_p.connect_roadpoint(RoadPoint.PointInit.NEXT, next_p_sibling, RoadPoint.PointInit.PRIOR)
				#next_p.connect_roadpoint(RoadPoint.PointInit.PRIOR, next_p_sibling, RoadPoint.PointInit.NEXT)
				#
				## create intersection
				#var intersection := RoadIntersection.new()
				#intersection.settings = IntersectionNGon.new()
				#intersection.add_branch(next_p)
				#intersection.add_branch(prior_p)
				#intersection.add_branch(edge_p)
				#
				#_loader.persist_in_current_scene(next_p)
				#_loader.persist_in_current_scene(prior_p)
				#_loader.persist_in_current_scene(intersection)
		
		elif group.size() > 2:
			print("Trying intersection: ", group)
			# TODO
			_intersections += 1


func _connect_rp_cross_container(n0: RoadPoint, n1: RoadPoint):
	# already connected: do nothing.
	if n0.cross_container_connected() or n1.cross_container_connected():
		return
	var from: RoadPoint.PointInit = RP_PRIOR
	var to: RoadPoint.PointInit = RP_PRIOR
	if n0.get_next_road_node() == null:
		from = RP_NEXT
	if n1.get_next_road_node() == null:
		to = RP_NEXT
	n0.copy_settings_from(n1)
	if from == to and to == RP_NEXT:
		n0.force_update_transform()
		n0.rotate_object_local(Vector3.UP, PI)
	# TODO equivalent prev/prev fix needed?
	n0.connect_container(from, n1, to)
	n0.container.rebuild_segments()
	n1.container.rebuild_segments()
