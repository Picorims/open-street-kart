extends RigidBody3D
var currentDirection: Vector3 = Vector3(1,0,0)
@export var accelerationForce: float = 3000
@export var rotationForce: float = 300

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var forwardBackward: float = Input.get_axis("backward", "forward")
	var leftRight: float = Input.get_axis("left", "right")
	#if (leftRight != 0):
		#currentDirection = currentDirection.rotated(global_transform.basis.y, 2*PI*0.01)
		#state.transform = state.transform.rotated(Vector3.UP, 2*PI*0.01)
	state.apply_central_force((forwardBackward * accelerationForce * basis.x))
	state.apply_torque(leftRight * rotationForce * Vector3(0,-1,0))
	#state.linear_velocity = state.linear_velocity.limit_length(10)
	pass

func _apply_wheel_adherence(state: PhysicsDirectBodyState3D) -> void:
	pass

func _process(delta: float) -> void:
	var debugPos = position + Vector3(0,3,0)
	DebugDraw3D.draw_arrow(debugPos, debugPos + linear_velocity, Color(0,0,1), 0.1)
	DebugDraw2D.set_text("Velocity", "%0.2f" % linear_velocity.length())
