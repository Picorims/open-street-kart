# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name RoadLinker extends Node3D

signal linked
const T_INTERSECT_SHIFT_DISTANCE_FACTOR: float = 2
const MOVE_SAFETY_GAP := 0.5
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
var _road_manager: RoadManager

func link_roads(road_manager: RoadManager, loader: MapDataLoader):
	print("Identifying road nodes to link...")
	_loader = loader
	_distances = {}
	_links = []
	_groups = []
	_attached_pairs = 0
	_t_intersections = 0
	_intersections = 0
	_road_manager = road_manager
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
				_create_t_intersection(n0, n1)
				_t_intersections += 1
		elif group.size() > 2:
			print("Trying intersection: ", group)
			var copy_arr: Array[RoadPoint] = []
			for p: RoadPoint in group:
				copy_arr.append(p)
			_create_intersection(copy_arr)
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

func _create_t_intersection(n0: RoadPoint, n1: RoadPoint):
	var continuous_p: RoadPoint
	var edge_p: RoadPoint
	if n0.get_prior_road_node() != null and n0.get_next_road_node() != null:
		continuous_p = n0
		edge_p = n1
	else:
		continuous_p = n1
		edge_p = n0
	var continuous_p_pos := continuous_p.global_position
	
	# first, move the edge out of the continuous road
	_move_rp_away(edge_p)
	
	# second, split the continuous point into two side points
	var next_p_sibling := continuous_p.get_next_road_node()
	var prior_p_sibling := continuous_p.get_prior_road_node()
	continuous_p.disconnect_roadpoint(RoadPoint.PointInit.NEXT, RoadPoint.PointInit.PRIOR)
	continuous_p.disconnect_roadpoint(RoadPoint.PointInit.PRIOR, RoadPoint.PointInit.NEXT)
	var next_p = RoadPoint.new()
	var prior_p = RoadPoint.new()
	
	var continuous_container: RoadContainer = continuous_p.get_parent()
	continuous_container.add_child(prior_p)
	_loader.persist_in_current_scene(prior_p)
	
	var road_container = RoadContainer.new()
	road_container.density = continuous_container.density
	road_container.collision_layer = continuous_container.collision_layer
	road_container.collision_mask = continuous_container.collision_mask
	road_container.use_lowpoly_preview = continuous_container.use_lowpoly_preview
	_road_manager.add_child(road_container)
	_loader.persist_in_current_scene(road_container)
	road_container.add_child(next_p)
	_loader.persist_in_current_scene(next_p)
	# we need to split the road into two containers, to then
	# be able to insert an intersection in between.
	var p: RoadPoint = next_p_sibling
	while p != null:
		p.reparent(road_container)
		p.container = road_container
		p = p.get_next_road_node()
	road_container.update_edges()
	continuous_container.update_edges()
	road_container.validate_edges()
	continuous_container.validate_edges()
	
	next_p.copy_settings_from(continuous_p)
	prior_p.copy_settings_from(continuous_p)
	next_p.force_update_transform()
	prior_p.force_update_transform()
	next_p.global_position = continuous_p_pos
	prior_p.global_position = continuous_p_pos
	#var continuous_axis = continuous_p.basis.x
	#next_p.position = continuous_p.position - continuous_axis * T_INTERSECT_SHIFT_DISTANCE_FACTOR
	#prior_p.position = continuous_p.position + continuous_axis * T_INTERSECT_SHIFT_DISTANCE_FACTOR
	next_p.connect_roadpoint(RoadPoint.PointInit.NEXT, next_p_sibling, RoadPoint.PointInit.PRIOR)
	prior_p.connect_roadpoint(RoadPoint.PointInit.PRIOR, prior_p_sibling, RoadPoint.PointInit.NEXT)
	_move_rp_away(next_p)
	_move_rp_away(prior_p)
	
	# create intersection
	_join_rps_into_intersection([next_p, edge_p, prior_p])
	continuous_container.rebuild_segments()
	road_container.rebuild_segments()
	continuous_p.queue_free()

## Assuming an edge RoadPoint, move it away on its linked axis.
## Distance corresponds to the road's width. 
func _move_rp_away(rp: RoadPoint) -> bool:
	if rp.get_next_road_node() == null and rp.get_prior_road_node() == null:
		push_warning("_move_rp_away(): cannot proceed, isolated point.")
		return false
	if rp.get_next_road_node() != null and rp.get_prior_road_node() != null:
		push_error("_move_rp_away(): cannot proceed, not an edge RoadPoint.")
		return false
	var dir := 1
	var sibling = rp.get_next_road_node()
	if rp.get_next_road_node() == null:
		dir = -1
		sibling = rp.get_prior_road_node()
	var width = rp.get_width_with_shoulders() + rp.gutter_profile.x * 2
	if not sibling == null:
		# avoid (or limit the risk that) the rp going beyond its sibling. 
		width = min(width, rp.global_position.distance_to(sibling.global_position) - MOVE_SAFETY_GAP)
		if width < 0:
			width = 0
	rp.global_position += rp.global_basis.z * dir * width
	return true

func _join_rps_into_intersection(rps: Array[RoadPoint]):
	var container := RoadContainer.new()
	_road_manager.add_child(container)
	_loader.persist_in_current_scene(container)
	var intersection := RoadIntersection.new()
	intersection.settings = IntersectionNGon.new()
	container.add_child(intersection)
	_loader.persist_in_current_scene(intersection)
	var avg_pos: Vector3 = Vector3.ZERO
	var edges: Array[RoadPoint] = []
	for p in rps:
		avg_pos += p.global_position
		var edge_rp := RoadPoint.new()
		container.add_child(edge_rp)
		_loader.persist_in_current_scene(edge_rp)
		edge_rp.copy_settings_from(p)
		edge_rp.global_position = p.global_position
		edges.append(edge_rp)
		if p.get_next_road_node() == null:
			p.connect_container(RP_NEXT, edge_rp, RP_PRIOR)
		else:
			p.connect_container(RP_PRIOR, edge_rp, RP_NEXT)
	avg_pos /= rps.size()
	intersection.global_position = avg_pos
	for e in edges:
		intersection.add_branch(e)

func _create_intersection(group: Array[RoadPoint]):
	for p: RoadPoint in group:
		_move_rp_away(p)
	_join_rps_into_intersection(group)
