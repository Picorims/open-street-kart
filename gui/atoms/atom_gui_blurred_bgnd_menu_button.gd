# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name AtomGUIBlurredBgndMenuButton extends Control

var _button: Button = Button.new()

@export var text: String = "?":
	set(v):
		text = v
		_button.text = v

func _ready() -> void:
	self.custom_minimum_size = Vector2(256,48)
	
	var colorRect: ColorRect = ColorRect.new()
	self.add_child(colorRect)
	colorRect.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	colorRect.color = Color.TRANSPARENT
	
	var shaderMat: ShaderMaterial = ShaderMaterial.new()
	shaderMat.shader = preload("res://shaders/blur_menu_button_background.gdshader")
	#shaderMat.set_shader_parameter("tint_color", Vector4(0,0,0,0.2))
	shaderMat.set_shader_parameter("samples", 4)
	shaderMat.set_shader_parameter("lod", 1)
	colorRect.material = shaderMat
	
	self.add_child(_button)
	_button.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_button.text = text
	#_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
