# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
extends VBoxContainer

@export var plugin: EditorPlugin
var path: String = ""
var dir: String = ""

func _on_pick_material_pressed() -> void:
	path = plugin.get_editor_interface().get_current_path()
	dir = plugin.get_editor_interface().get_current_directory()
	$HBoxContainer/Path.text = path
	pass # Replace with function body.



func _on_channel_pack_pressed() -> void:
	if path == "":
		$Status.text = "Please pick a material first."
		return
	var content = load(path)
	if not is_instance_of(content, StandardMaterial3D):
		$Status.text = "Cannot proceed, selected path is not an instance of StandardMaterial3D"
		return
	var mat: StandardMaterial3D = content
	var albedo_src = mat.albedo_texture.get_image()
	var normal_src = mat.normal_texture.get_image()
	var height_src = mat.heightmap_texture.get_image()
	var amb_occ_rough_src = mat.roughness_texture.get_image()
	albedo_src.decompress()
	normal_src.decompress()
	height_src.decompress()
	amb_occ_rough_src.decompress()
	
	var albedo_height_img = Image.create_empty(albedo_src.get_width(), albedo_src.get_height(), true, Image.Format.FORMAT_RGBA8)
	for x in albedo_height_img.get_width():
		for y in albedo_height_img.get_height():
			var albedo: Color = albedo_src.get_pixel(x,y)
			var height: Color = height_src.get_pixel(x,y)
			var amb_occ: float = amb_occ_rough_src.get_pixel(x,y).r
			albedo_height_img.set_pixel(x,y, Color(albedo.r * amb_occ, albedo.g * amb_occ, albedo.b * amb_occ, height.r))
	
	var normal_rough_img = Image.create_empty(normal_src.get_width(), normal_src.get_height(), true, Image.FORMAT_RGBA8)
	for x in normal_rough_img.get_width():
		for y in normal_rough_img.get_height():
			var normal: Color = normal_src.get_pixel(x,y)
			var rough: float = amb_occ_rough_src.get_pixel(x,y).g
			normal_rough_img.set_pixel(x,y, Color(normal.r, normal.g, normal.b, rough))
	
	var albedo_path: String = _get_albedo_path()
	var normal_path: String = get_normal_path()
	albedo_height_img.save_png(albedo_path)
	normal_rough_img.save_png(normal_path)
	$Info.text = "Packed %s into %s and %s." % [path, albedo_path, normal_path]

func _get_albedo_path():
	return path.replace(".tres", "_t3d_albedo_ao_height.png")

func get_normal_path():
	return path.replace(".tres", "_t3d_normal_rough.png")

func _on_fix_import_pressed() -> void:
	if path == "":
		$Status.text = "Please pick a material first."
		return
	var content = load(path)
	if not is_instance_of(content, StandardMaterial3D):
		$Status.text = "Cannot proceed, selected path is not an instance of StandardMaterial3D"
		return
	var albedo_path: String = _get_albedo_path()
	var normal_path: String = get_normal_path()
	if FileAccess.file_exists(albedo_path) and FileAccess.file_exists(normal_path):
		if FileAccess.file_exists(albedo_path + ".import") and FileAccess.file_exists(normal_path + ".import"):
			_fix_import_file(albedo_path)
			_fix_import_file(normal_path)
			var editor_file_system := plugin.get_editor_interface().get_resource_filesystem()
			editor_file_system.reimport_files([albedo_path, normal_path])
			$Status.text = "Fixed Channel packed image import files."
		else:
			$Status.text = "Channel packed image import files not found. Please import images first."
	else:
		$Status.text = "Channel packed images not found."

func _fix_import_file(img_path: String):
	var full_path = img_path + ".import"
	print("Fixing %s" % [full_path])
	var file_access = FileAccess.open(full_path, FileAccess.READ)
	var new_content = ""
	while not file_access.eof_reached():
		var line: String = file_access.get_line()
		if line.begins_with("compress/mode"):
			new_content += "compress/mode=2" # TODO find where is the enum.
		elif line.begins_with("compress/normal_map"):
			new_content += "compress/normal_map=2" # TODO find where is the enum.
		elif line.begins_with("mipmaps/generate"):
			new_content += "mipmaps/generate=true"
		else:
			new_content += line
		new_content += "\n"
	file_access.close()
	var file_write = FileAccess.open(full_path, FileAccess.WRITE_READ)
	file_write.store_string(new_content)
	file_write.close()
	print("Fixed %s" % [full_path])
