# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


@tool
extends Node3D

@export_tool_button("reload") var btn = reload_mesh
func reload_mesh():
	print("reloading...")
	var children = self.get_children()
	for c in children:
		self.remove_child(c)
		c.queue_free()
		
	print("making road...")
	var path = Path3D.new()
	var curve = Curve3D.new()
	var csgPoly = CSGPolygon3D.new()
	csgPoly.use_collision = true
	curve.add_point(Vector3(1,2,3))
	curve.add_point(Vector3(4,2,6))
	curve. add_point(Vector3(7,2,9))
	path.curve = curve
	csgPoly.add_child(path)
	self.add_child(csgPoly)
	# stops rendering as soon as the following two lines are enabled
	#csgPoly.mode = CSGPolygon3D.MODE_PATH
	#csgPoly.path_node = ^"Path3D"
	# failed fix attempts
	#print("bake collision")
	#csgPoly.bake_collision_shape()
	#print("bake mesh")
	#csgPoly.bake_static_mesh()
