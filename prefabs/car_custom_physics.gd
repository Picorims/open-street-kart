extends RigidBody3D
var currentDirection: Vector3 = Vector3(1,0,0)
@export var accelerationForce: float = 3000
@export var rotationForce: float = 300
@export var speedMultiplier: float = 1.0

var _debugCentrifugusForce: Vector3
var _debugSlidingForce: Vector3

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var forwardBackward: float = Input.get_axis("backward", "forward")
	var leftRight: float = Input.get_axis("left", "right")

	_cancel_inertia(state)
	_apply_wheel_adherence(state)

	state.apply_central_force((forwardBackward * accelerationForce * speedMultiplier * basis.x))
	state.apply_torque(leftRight * rotationForce * Vector3(0,-1,0))

# applied on x,z plan
func _cancel_inertia(state: PhysicsDirectBodyState3D) -> void:
	var radius: float = _get_radius_of_rotation(state)
	var centrifugusDirection: Vector3 = basis.z.normalized() * sign(state.angular_velocity.y)
	if (centrifugusDirection.length() < 0.01):
		return
	var centrifugusForce: Vector3 = centrifugusDirection * (mass * state.linear_velocity.length_squared() / radius)
	state.apply_central_force(-centrifugusForce)
	_debugCentrifugusForce = centrifugusForce

# applied on x,z plan
func _get_radius_of_rotation(state: PhysicsDirectBodyState3D) -> float:
	# assuming a circle arc of length <previous pos to current pos>,
	# of angle length equal to previous angular velocity,
	# we compute the circumference of the entire circle,
	# and deduct a radius from there
	var length = (state.linear_velocity * Vector3(1,0,1)).length()
	var angle = abs(state.angular_velocity.y)
	var circumference = (2*PI / angle) * length
	var radius = circumference / (2*PI)
	return radius

# FIXME broken!!!
func _apply_wheel_adherence(state: PhysicsDirectBodyState3D) -> void:
	if (_wheels_on_ground() < 2):
		_debugSlidingForce = Vector3(0,0,0)
		return
	var normalToGround: Vector3 = basis.y.normalized()
	var groundCounterForce: Vector3 = normalToGround * (get_gravity() * self.gravity_scale).length()
	var slidingForce: Vector3 = (get_gravity() + groundCounterForce) * mass
	_debugSlidingForce = slidingForce
	var z: Vector3 = basis.z.normalized()
	state.apply_central_force(z * -slidingForce.dot(z))

func _wheels_on_ground() -> int:
	var wheelsOnGround: int = 0
	if ($WheelFRRayCast3D.is_colliding()):
		wheelsOnGround += 1
	if ($WheelBLRayCast3D.is_colliding()):
		wheelsOnGround += 1
	if ($WheelBRRayCast3D.is_colliding()):
		wheelsOnGround += 1
	if ($WheelFLRayCast3D.is_colliding()):
		wheelsOnGround += 1
		
	return wheelsOnGround

func _input(event):
	if (event.is_action_pressed("toggle_cam")):
		$Camera3D.current = !$Camera3D.current

func _process(_delta: float) -> void:
	# debug
	var debugPos = global_position + Vector3(0,3,0)
	DebugDraw3D.draw_arrow(debugPos, debugPos + linear_velocity, Color(0,0,1), 0.1)
	DebugDraw2D.set_text("Velocity", "%0.2f" % linear_velocity.length())
	DebugDraw3D.draw_arrow(debugPos, debugPos + _debugCentrifugusForce, Color(0,1,0), 0.1)
	DebugDraw3D.draw_arrow(debugPos, debugPos + _debugSlidingForce, Color(1,0,0), 0.1)
