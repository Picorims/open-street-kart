extends RigidBody3D

var raycast_fl: RayCast3D;
var raycast_fr: RayCast3D;
var raycast_bl: RayCast3D;
var raycast_br: RayCast3D;

@export var MAX_STEER = 0.9;
@export var ENGINE_POWER = 3000;
@export var SPRING_FORCE = 3000;

func _ready():
	raycast_bl = get_node("RayCast3D BL")
	raycast_br = get_node("RayCast3D BR")
	raycast_fl = get_node("RayCast3D FL")
	raycast_fr = get_node("RayCast3D FR")
	

func _interpol_squared(x):
	return x*x

func _apply_raycast_force(raycast: RayCast3D):
	if (raycast.is_colliding()):
		var raycast_length = raycast.global_position.length()
		var collision_point: Vector3 = raycast.get_collision_point()
		var collision_distance: float = (raycast.global_position - collision_point).length()
		var force_to_apply: float = 1 - collision_distance / raycast.target_position.length()
		var force_direction: Vector3 = get_global_transform_interpolated().basis.y.normalized()
		
		# interpolate then apply
		force_to_apply = _interpol_squared(force_to_apply)
		apply_force(force_direction * force_to_apply * SPRING_FORCE, raycast.global_position)
	
func _physics_process(delta: float) -> void:
	_apply_raycast_force(raycast_fl)
	_apply_raycast_force(raycast_fr)
	_apply_raycast_force(raycast_bl)
	_apply_raycast_force(raycast_br)
	
	var aim = get_global_transform_interpolated().basis
	# move the car left/right
	apply_torque(Vector3(0,1,0) * Input.get_axis("right", "left") * MAX_STEER)
	# move the car forward
	apply_force(-aim.z * Input.get_axis("forward", "backward") * ENGINE_POWER)
	
