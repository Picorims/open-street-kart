extends Node3D

func _ready() -> void:
	if $Sky3D/MoonLight.visible == false:
		$Sky3D/MoonLight.visible = true
