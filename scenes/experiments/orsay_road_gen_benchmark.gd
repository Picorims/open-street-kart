extends Node3D

func _ready() -> void:
	print("GOGOGO")
	var loader: MapDataLoader = self.get_node("MapDataLoader")
	loader._reload_surface_action()
	loader._reload_boundaries_action()
	loader._reload_osm_action()
