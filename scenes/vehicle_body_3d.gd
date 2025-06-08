extends VehicleBody3D

@export var MAX_STEER = 0.9;
@export var ENGINE_POWER = 3000;

func _physics_process(delta: float) -> void:
	# move the car left/right
	steering = move_toward(steering, Input.get_axis("right", "left") * MAX_STEER, delta * 10)
	# move the car forward
	engine_force = Input.get_axis("backward", "forward") * ENGINE_POWER
