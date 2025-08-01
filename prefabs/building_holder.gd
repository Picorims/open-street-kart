class_name BuildingHolder extends Node3D

@export var collider: CollisionShape3D = null
@export var player: Node3D = null

#func _ready() -> void:
	#print("alive")

#func _process(delta: float) -> void:
	#if (collider != null && player != null):
		#var loaded: bool = collider.global_position.distance_squared_to(player.global_position) > 100*100
		#collider.disabled = !loaded
		#self.visible = loaded
		#
