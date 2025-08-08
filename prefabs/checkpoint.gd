@tool
class_name Checkpoint extends Node3D

@export var boxSize: Vector3 = Vector3(5,5,5):
	set(v):
		boxSize = v
		_update_box()


func _ready() -> void:
	_update_box()
	var area: Area3D = $Area3D
	area.monitoring = true
	area.body_entered.connect(func (body: Node3D):
		var car: Node3D = body.get_parent_node_3d()
		if (car != null && is_instance_of(car, CarCustomPhysics2)):
			car.lastCheckpoint = self
			
	)

func _process(delta: float) -> void:
	DebugDraw3D.draw_box(self.position, self.basis.get_rotation_quaternion(), boxSize, Color(0,0.8,0.3), true)

func _update_box():
	var collShapeNode: CollisionShape3D = $"Area3D/CollisionShape3D"
	if (collShapeNode == null):
		print("ERROR: collision shape undefined, this should not happen!")
		return
	var shape: BoxShape3D = collShapeNode.shape
	shape.size = boxSize
	
