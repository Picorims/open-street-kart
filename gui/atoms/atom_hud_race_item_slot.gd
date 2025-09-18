# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name AtomHUDRaceItemSlot extends Control

@export var size_pixels: int:
	set(v):
		size_pixels = v
		custom_minimum_size = Vector2(v,v)
		update_minimum_size()
		_shader_mat.set_shader_parameter("corner_radius", size_pixels)
		_shader_mat.set_shader_parameter("texture_width", size_pixels)
		_shader_mat.set_shader_parameter("texture_height", size_pixels)
		
var _shader_mat: ShaderMaterial = ShaderMaterial.new()

func _ready() -> void:
	self.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	custom_minimum_size = Vector2(size_pixels, size_pixels)
	
	var background: ColorRect = ColorRect.new()
	self.add_child(background)
	background.set_anchors_preset(Control.LayoutPreset.PRESET_FULL_RECT, true)
	
	_shader_mat.shader = preload("res://shaders/blur_with_radius_background.gdshader")
	_shader_mat.set_shader_parameter("corner_radius", size_pixels)
	_shader_mat.set_shader_parameter("texture_width", size_pixels)
	_shader_mat.set_shader_parameter("texture_height", size_pixels)
	_shader_mat.set_shader_parameter("strength", 4.0)
	_shader_mat.set_shader_parameter("mix_color", Vector3(0.094, 0.231, 0.259))
	_shader_mat.set_shader_parameter("mix_percentage", 0.5)
	background.material = _shader_mat
