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

func _ready() -> void:
	assert(self.global_position.is_equal_approx(Vector3(0,0,0)), "RacePath should be at the origin.")

func _bake_path():
	if (startingNode == null):
		print("Please specify a starting node. This is necessary for baking the path. (Do not forget successors as well)")
		return
	print("Baking race path...")
	var newCurve: Curve3D = Curve3D.new()
	newCurve.add_point(startingNode.position)
	
	var queue: Array[RacePathNode] = []
	queue.append(startingNode.successor)
	
	var index: int = 0
	
	#TODO support branching
	while queue.size()-1 >= index:
		print(index)
		newCurve.add_point(queue[index].position)
		if (queue[index].successor != null):
			queue.append(queue[index].successor)
		index += 1
		
		if index > MAX_POINTS:
			print("WARNING: Max points exceeded, stopping exploration. Are there loops?")
			break
	
	self.curve = newCurve
	print("done")
