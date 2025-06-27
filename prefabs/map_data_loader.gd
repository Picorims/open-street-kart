@tool
class_name MapDataLoader extends Node3D

@export var topoDataPath: String
@export var osmDataPath: String
@export var latitudeScale = 111320
@export var longitudeScale = 111320
@export_tool_button("Reload") var reload_action = Callable(self, "_reload_action")
@export var floorMaterial: Material

func _reload_action():
	print("=== reloading elevation ===")
	$Surface.reload_action(floorMaterial)
	print ("=== reloading done ===")
