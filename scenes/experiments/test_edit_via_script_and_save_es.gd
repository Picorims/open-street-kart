@tool
extends EditorScript

func mark_as_unsaved() -> void:
	get_editor_interface().mark_scene_as_unsaved()
