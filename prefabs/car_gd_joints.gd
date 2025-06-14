extends Node3D

@export var MAX_STEER = 1000
@export var ENGINE_POWER = 3000

func _physics_process(delta: float) -> void:
	var aim = $CarFrame.get_global_transform_interpolated().basis
	# move the car left/right
	$CarFrame.apply_torque(Vector3(0,1,0) * Input.get_axis("right", "left") * MAX_STEER)
	# steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	# move the car forward
	$CarFrame.apply_force(-aim.x * Input.get_axis("forward", "backward") * ENGINE_POWER)
	# engine_force = Input.get_axis("backward", "forward") * ENGINE_POWER
