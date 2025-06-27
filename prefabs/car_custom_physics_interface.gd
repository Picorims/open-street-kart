extends Node3D

@export var speedMultiplier: float = 1.0:
	set(v):
		speedMultiplier = v
		$CarRigidBody.speedMultiplier = v
