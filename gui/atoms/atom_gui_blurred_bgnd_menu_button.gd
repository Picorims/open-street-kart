# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name AtomGUIBlurredBgndMenuButton extends Control

var _button: Button = Button.new()
signal pressed

@export var text: String = "?":
	set(v):
		text = v
		_button.text = v

func _ready() -> void:
	self.custom_minimum_size = Vector2(256, 48)
	
	var color_rect: ColorRect = ColorRect.new()
	self.add_child(color_rect)
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	color_rect.color = Color.TRANSPARENT
	
	var shader_mat: ShaderMaterial = ShaderMaterial.new()
	shader_mat.shader = preload("res://shaders/blur_menu_button_background.gdshader")
	#shaderMat.set_shader_parameter("tint_color", Vector4(0,0,0,0.2))
	shader_mat.set_shader_parameter("strength", 4)
	shader_mat.set_shader_parameter("mix_percentage", 0)
	color_rect.material = shader_mat
	
	self.add_child(_button)
	_button.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_button.text = text
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	_button.pressed.connect(func(): pressed.emit())
