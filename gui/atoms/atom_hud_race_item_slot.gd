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
var _progress: TextureProgressBar = preload("res://gui/atoms/atom_hud_progress_bar_radial.tscn").instantiate()
var _image: TextureRect = TextureRect.new()
var _texture_atlas: Dictionary[PlayerItemSlotsState.SlotItem, Texture2D] = {
	PlayerItemSlotsState.SlotItem.EMPTY: preload("res://textures/hud/slot_item/empty_status_icon.png"),
	PlayerItemSlotsState.SlotItem.SPEED_BOOST: preload("res://textures/hud/slot_item/item_slot_speed_boost.png"),
	PlayerItemSlotsState.SlotItem.AIR_BOMB: preload("res://textures/hud/slot_item/item_slot_air_bomb.png"),
}

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
	
	self.add_child(_progress)
	_progress.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	
	var _image_margin: MarginContainer = MarginContainer.new()
	self.add_child(_image_margin)
	_image_margin.set_anchors_preset(PRESET_FULL_RECT, true)
	const MARGIN = 8
	_image_margin.add_theme_constant_override("margin_top", MARGIN)
	_image_margin.add_theme_constant_override("margin_bottom", MARGIN)
	_image_margin.add_theme_constant_override("margin_left", MARGIN)
	_image_margin.add_theme_constant_override("margin_right", MARGIN)
	_image_margin.add_child(_image)
	_image.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH

## Update the slot icon
func set_item(item: PlayerItemSlotsState.SlotItem) -> void:
	if (item == PlayerItemSlotsState.SlotItem.DISABLED):
		_image.texture = null
		return
	
	if (item == PlayerItemSlotsState.SlotItem.EMPTY):
		_image.modulate = Color(1,1,1,0.5)
	else:
		_image.modulate = Color(1,1,1,1)
	
	_image.texture = _texture_atlas.get(item)
	
## Update the slot progress display based on a ratio (0 to 1)
func set_progress_ratio(ratio: float) -> void:
	_progress.value = ratio
