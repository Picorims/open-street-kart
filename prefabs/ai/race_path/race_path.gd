# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool

## Path followed by AIs, determined by the list of children RacePathNode instances connected
## to each other
class_name RacePath extends Path3D

@export_tool_button("Bake Path", "Path3D") var bake_path_action: Callable = Callable(self, "_bake_path")
@export var starting_node: RacePathNode

const MAX_POINTS: int = 10_000
## controls the intensity of bezier smoothing.
const DISTANCE_DIVIDER: float = 3
const FORWARD_VECTOR_TOO_SMALL_THRESHOLD = 0.01

var _found_race_path_nodes: Array[RacePathNode] = []
var _nodes_offset: Array[float] = []

func _ready() -> void:
	assert(self.global_position.is_equal_approx(Vector3(0, 0, 0)), "RacePath should be at the origin.")
	_bake_path() # necessary for runtime (otherwise found race path nodes and offsets are empty

func _bake_path():
	if (starting_node == null):
		print("Please specify a starting node. This is necessary for baking the path. (Do not forget successors as well)")
		return
	if (starting_node.successor == null):
		print("No successor found for starting node, cannot bake path.")
		return
	print("Baking race path...")
	var new_curve: Curve3D = Curve3D.new()
	new_curve.bake_interval = 2
	var new_nodes: Array[RacePathNode] = []
	var new_nodes_offset: Array[float] = []
	new_curve.add_point(starting_node.position)
	new_nodes.append(starting_node)


	var queue: Array[RacePathNode] = []
	queue.append(starting_node.successor)
	
	var index: int = 0
	
	#TODO support branching
	while queue.size() - 1 >= index:
		new_nodes.append(queue[index])
		new_curve.add_point(queue[index].position)
		if (queue[index].successor != null):
			queue.append(queue[index].successor)
		index += 1
		
		if index > MAX_POINTS:
			print("WARNING: Max points exceeded, stopping exploration. Are there loops?")
			break
	
	print("Smooth curve...")
	# place in and out points at half distance to sibling
	# along [prev,next] axis.
	for i in range(1, new_curve.point_count - 1):
		var prev_point: Vector3 = new_curve.get_point_position(i - 1)
		var curr_point: Vector3 = new_curve.get_point_position(i)
		var next_point: Vector3 = new_curve.get_point_position(i + 1)
		var prev_dist: float = prev_point.distance_to(curr_point)
		var next_dist: float = curr_point.distance_to(next_point)
		var axis: Vector3 = (next_point - prev_point).normalized()
		new_curve.set_point_in(i, - (axis * (prev_dist / DISTANCE_DIVIDER)))
		new_curve.set_point_out(i, (axis * (next_dist / DISTANCE_DIVIDER)))
		
	for i in range(0, new_curve.point_count):
		new_nodes_offset.append(new_curve.get_closest_offset(new_curve.get_point_position(i)))
	
	assert(
		new_nodes.size() == new_nodes_offset.size() && new_nodes_offset.size() == new_curve.point_count,
		"ERROR: path data is not consistent: {0} {1} {2}".format([new_nodes.size(), new_nodes_offset.size(), new_curve.point_count]))
	
	self.curve = new_curve
	_found_race_path_nodes = new_nodes
	_nodes_offset = new_nodes_offset
	print("done")

class QueryInfo:
	var prev: RacePathNode
	var next: RacePathNode
	var closest_offset: float
	var closest_point: Vector3
	var prev_offset: float
	var next_offset: float
	## z is forward, x is left, y is top.
	var forward_basis: Basis

static var closest_offset_accumulated_us: float = 0
static var closest_point_accumulated_us: float = 0
static var basis_accumulated_us: float = 0
static var loops_accumulated_us: float = 0
var checkpoint_us: float = 0

func query_info(pos: Vector3) -> QueryInfo:
	var q: QueryInfo = QueryInfo.new()

	checkpoint_us = Time.get_ticks_usec()
	# Very expensive
	q.closest_offset = curve.get_closest_offset(pos)
	closest_offset_accumulated_us += Time.get_ticks_usec() - checkpoint_us

	checkpoint_us = Time.get_ticks_usec()
	q.closest_point = curve.sample_baked(q.closest_offset)
	closest_point_accumulated_us += Time.get_ticks_usec() - checkpoint_us

	var a_bit_forward_point: Vector3 = curve.sample_baked(q.closest_offset + 2 * curve.bake_interval)
	var forward_normalized = (a_bit_forward_point - q.closest_point).normalized()
	
	checkpoint_us = Time.get_ticks_usec()
	var found_next: bool = false
	var i: int = 0
	while (!found_next && i < _nodes_offset.size()):
		if (_nodes_offset[i] > q.closest_offset):
			q.next = _found_race_path_nodes[i]
			q.next_offset = _nodes_offset[i]
			if (i > 0):
				q.prev = _found_race_path_nodes[i - 1]
				q.prev_offset = _nodes_offset[i - 1]
			found_next = true
		i += 1
	loops_accumulated_us += Time.get_ticks_usec() - checkpoint_us
	
	checkpoint_us = Time.get_ticks_usec()
	var failed_basis: bool = false
	if (forward_normalized.length_squared() < FORWARD_VECTOR_TOO_SMALL_THRESHOLD):
		forward_normalized = curve.sample_baked(q.closest_offset + 6 * curve.bake_interval)
		forward_normalized = (forward_normalized - q.closest_point).normalized()
		if (forward_normalized.length_squared() < FORWARD_VECTOR_TOO_SMALL_THRESHOLD):
			failed_basis = true
		else:
			q.forward_basis = Basis(forward_normalized, 0)
	else:
		q.forward_basis = Basis(forward_normalized, 0)

	# try to approximate with control points as a last resort
	if (failed_basis):
		if (q.prev != null && q.next != null):
			q.forward_basis = Basis((q.next.global_position - q.prev.global_position).normalized(), 0)
		else:
			# failed.
			q.forward_basis = Basis()
	basis_accumulated_us += Time.get_ticks_usec() - checkpoint_us
	
	return q

func _process(_delta: float) -> void:
	pass
	#DebugDraw2D.set_text("closest_offset_accumulated_us", closest_offset_accumulated_us)
	#DebugDraw2D.set_text("closest_point_accumulated_us", closest_point_accumulated_us)
	#DebugDraw2D.set_text("basis_accumulated_us", basis_accumulated_us)
	#DebugDraw2D.set_text("loops_accumulated_us", loops_accumulated_us)
