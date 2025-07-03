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
	curve.add_point(Vector3(4,5,6))
	curve. add_point(Vector3(7,8,9))
	path.curve = curve
	csgPoly.add_child(path)
	self.add_child(csgPoly)
	# stops rendering as soon as the following two lines are enabled
	csgPoly.mode = CSGPolygon3D.MODE_PATH
	csgPoly.path_node = ^"Path3D"
	# failed fix attempts
	print("bake collision")
	csgPoly.bake_collision_shape()
	print("bake mesh")
	csgPoly.bake_static_mesh()
