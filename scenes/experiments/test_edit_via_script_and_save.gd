@tool
extends Node3D

const editorScript = preload("res://scenes/experiments/test_edit_via_script_and_save_es.gd")
@export_tool_button("run") var button: Callable = Callable(self, "run")

func run() -> void:
	var node = Node3D.new()
	self.add_child(node)
	node.owner = get_tree().edited_scene_root
	print("added node ", node.name)
	#editorScript.mark_as_unsaved()
