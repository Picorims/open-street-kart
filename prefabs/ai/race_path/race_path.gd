# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool

## Path followed by AIs, determined by the list of children RacePathNode instances connected
## to each other
class_name RacePath extends Path3D

@export_tool_button("Bake Path", "Path3D") var bakePathAction: Callable = Callable(self, "_bake_path")
@export var startingNode: RacePathNode

const MAX_POINTS: int = 10_000
const DISTANCE_DIVIDER: float = 3

var _foundRacePathNodes: Array[RacePathNode] = []
var _nodesOffset: Array[float] = []

func _ready() -> void:
	assert(self.global_position.is_equal_approx(Vector3(0,0,0)), "RacePath should be at the origin.")
	_bake_path() # necessary for runtime (otherwise found race path nodes and offsets are empty

func _bake_path():
	if (startingNode == null):
		print("Please specify a starting node. This is necessary for baking the path. (Do not forget successors as well)")
		return
	if (startingNode.successor == null):
		print("No successor found for starting node, cannot bake path.")
		return
	print("Baking race path...")
	var newCurve: Curve3D = Curve3D.new()
	newCurve.bake_interval = 1
	var newNodes: Array[RacePathNode] = []
	var newNodesOffset: Array[float] = []
	newCurve.add_point(startingNode.position)
	newNodes.append(startingNode)


	
	var queue: Array[RacePathNode] = []
	queue.append(startingNode.successor)
	
	var index: int = 0
	
	#TODO support branching
	while queue.size()-1 >= index:
		newNodes.append(queue[index])
		newCurve.add_point(queue[index].position)
		if (queue[index].successor != null):
			queue.append(queue[index].successor)
		index += 1
		
		if index > MAX_POINTS:
			print("WARNING: Max points exceeded, stopping exploration. Are there loops?")
			break
	
	print("Smooth curve...")
	# place in and out points at half distance to sibling
	# along [prev,next] axis.
	for i in range(1, newCurve.point_count - 1):
		var prevPoint: Vector3 = newCurve.get_point_position(i-1)
		var currPoint: Vector3 = newCurve.get_point_position(i)
		var nextPoint: Vector3 = newCurve.get_point_position(i+1)
		var prevDist: float = prevPoint.distance_to(currPoint)
		var nextDist: float = currPoint.distance_to(nextPoint)
		var axis: Vector3 = (nextPoint - prevPoint).normalized()
		newCurve.set_point_in(i, -(axis * (prevDist / DISTANCE_DIVIDER)))
		newCurve.set_point_out(i, (axis * (nextDist / DISTANCE_DIVIDER)))
		
	for i in range(0, newCurve.point_count):
		newNodesOffset.append(newCurve.get_closest_offset(newCurve.get_point_position(i)))
	
	assert(
		newNodes.size() == newNodesOffset.size() && newNodesOffset.size() == newCurve.point_count,
		"ERROR: path data is not consistent: {0} {1} {2}".format([newNodes.size(), newNodesOffset.size(), newCurve.point_count]))
	
	self.curve = newCurve
	_foundRacePathNodes = newNodes
	_nodesOffset = newNodesOffset
	print("done")

class QueryInfo:
	var prev: RacePathNode
	var next: RacePathNode
	var closestOffset: float
	var closestPoint: Vector3
	var prevOffset: float
	var nextOffset: float
	## z is forward, x is left, y is top.
	var forwardBasis: Basis

static var closestOffsetAccumulatedUs: float = 0
static var closestPointAccumulatedUs: float = 0
static var basisAccumulatedUs: float = 0
static var loopsAccumulatedUs: float = 0
var checkpointUs: float = 0

func query_info(pos: Vector3) -> QueryInfo:
	var q: QueryInfo = QueryInfo.new()

	checkpointUs = Time.get_ticks_usec()
	# Very expensive
	q.closestOffset = curve.get_closest_offset(pos)
	closestOffsetAccumulatedUs += Time.get_ticks_usec() - checkpointUs

	checkpointUs = Time.get_ticks_usec()
	q.closestPoint = curve.sample_baked(q.closestOffset)
	closestPointAccumulatedUs += Time.get_ticks_usec() - checkpointUs

	var aBitForwardPoint: Vector3 = curve.sample_baked(q.closestOffset + 2 * curve.bake_interval)
	var forwardNormalized = (aBitForwardPoint - q.closestPoint).normalized()
	checkpointUs = Time.get_ticks_usec()
	q.forwardBasis = Basis(forwardNormalized, 0)
	basisAccumulatedUs += Time.get_ticks_usec() - checkpointUs
	
	checkpointUs = Time.get_ticks_usec()
	var foundNext: bool = false
	var i: int = 0
	while (!foundNext && i < _nodesOffset.size()):
		if (_nodesOffset[i] > q.closestOffset):
			q.next = _foundRacePathNodes[i]
			q.nextOffset = _nodesOffset[i]
			if (i > 0):
				q.prev = _foundRacePathNodes[i-1]
				q.prevOffset = _nodesOffset[i-1]
			foundNext = true
		i += 1
	
	loopsAccumulatedUs += Time.get_ticks_usec() - checkpointUs
	return q

func _process(delta: float) -> void:
	pass
	#DebugDraw2D.set_text("closestOffsetAccumulatedUs", closestOffsetAccumulatedUs)
	#DebugDraw2D.set_text("closestPointAccumulatedUs", closestPointAccumulatedUs)
	#DebugDraw2D.set_text("basisAccumulatedUs", basisAccumulatedUs)
	#DebugDraw2D.set_text("loopsAccumulatedUs", loopsAccumulatedUs)
