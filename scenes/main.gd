# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node3D

const _3D_MENU_BACKGROUND: PackedScene = preload("res://scenes/backgrounds/gui_background_menus.tscn")

const _SCREEN_PICK_MODE: PackedScene = preload("res://gui/screens/pick_mode_screen.tscn")

enum _BackgroundKind {
	UNSET,
	MENU_BACKGROUND_3D
}

enum _Screen {
	NONE,
	PICK_MODE
}

var _currentBackground: _BackgroundKind = _BackgroundKind.UNSET
var _currentScreen: _Screen = _Screen.NONE

func _ready():
	print("Loading...")
	_show_mode_menu()
	print("done.")

func _show_mode_menu():
	_apply_background(_BackgroundKind.MENU_BACKGROUND_3D)
	_apply_screen(_Screen.PICK_MODE)

## If screen is different, apply it.
func _apply_screen(screenKind: _Screen):
	if (_currentScreen != screenKind):
		if (screenKind == _Screen.PICK_MODE):
			_clear_gui()
			var newScreen: Control = _SCREEN_PICK_MODE.instantiate()
			$GUI.add_child(newScreen)

## If background is different, apply it.
func _apply_background(backgroundKind: _BackgroundKind):
	if (_currentBackground != backgroundKind):
		if (backgroundKind == _BackgroundKind.MENU_BACKGROUND_3D):
			_clear_world()
			var env: Node3D = _3D_MENU_BACKGROUND.instantiate() 
			$World.add_child(env)

## Remove all children of $World
func _clear_world():
	for c in $World.get_children():
		$World.remove_child(c)
		c.queue_free()
		
func _clear_gui():
	for c in $GUI.get_children():
		$GUI.remove_child(c)
		c.queue_free()
