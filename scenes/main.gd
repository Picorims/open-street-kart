# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name Main extends Node3D

const _3D_MENU_BACKGROUND: PackedScene = preload("res://scenes/backgrounds/gui_background_menus.tscn")

const _SCREEN_PICK_MODE: PackedScene = preload("res://gui/screens/pick_mode_screen.tscn")
const _SCREEN_PICK_SPEED: PackedScene = preload("res://gui/screens/pick_speed_screen.tscn")
const _SCREEN_PICK_TRACK: PackedScene = preload("res://gui/screens/pick_track_screen.tscn")

enum _BackgroundKind {
	UNSET,
	MENU_BACKGROUND_3D
}

enum _Screen {
	NONE,
	PICK_MODE,
	PICK_SPEED,
	PICK_TRACK,
}

enum Track {
	NONE,
	ORSAY_HILLS,
}

const TRACK_SCENES: Dictionary[Main.Track, PackedScene] = {
	Track.ORSAY_HILLS: preload("res://scenes/races/orsay.tscn")
}

var _currentBackground: _BackgroundKind = _BackgroundKind.UNSET
var _currentScreen: _Screen = _Screen.NONE

var _selectedMode: TrackState.GameMode
var _selectedSpeed: TrackState.SpeedMode
var _trackToLoad: Main.Track = Main.Track.NONE
var _awaitingTrackToLoad: bool = false
var _awaitingTrackToLoadSince: float = 0
const TRACK_LOAD_DELAY_MS = 100

func get_selected_mode() -> TrackState.GameMode:
	return _selectedMode

func get_selected_speed() -> TrackState.SpeedMode:
	return _selectedSpeed

func _ready():
	print("Loading...")
	_show_mode_menu()
	print("Loading done.")

func _show_mode_menu():
	_apply_background(_BackgroundKind.MENU_BACKGROUND_3D)
	_apply_screen(_Screen.PICK_MODE)

## If screen is different, apply it.
func _apply_screen(screenKind: _Screen):
	if (_currentScreen != screenKind):
		if (screenKind == _Screen.PICK_MODE):
			print("opening pick mode screen")
			_clear_gui()
			var newScreen: PickModeScreen = _SCREEN_PICK_MODE.instantiate()
			$GUI.add_child(newScreen)
			newScreen.mode_selected.connect(func(mode: TrackState.GameMode):
				_selectedMode = mode
				_apply_screen(_Screen.PICK_SPEED)
			)
		if (screenKind == _Screen.PICK_SPEED):
			print("opening pick speed screen")
			_clear_gui()
			var newScreen: PickSpeedScreen = _SCREEN_PICK_SPEED.instantiate()
			$GUI.add_child(newScreen)
			newScreen.mode_selected.connect(func(mode: TrackState.SpeedMode):
				_selectedSpeed = mode
				_apply_screen(_Screen.PICK_TRACK)
			)
		if (screenKind == _Screen.PICK_TRACK):
			print("opening pick track screen")
			_clear_gui()
			var newScreen: PickTrackScreen = _SCREEN_PICK_TRACK.instantiate()
			$GUI.add_child(newScreen)
			newScreen.track_selected.connect(func(track: Main.Track):
				_launch_track(track)
			)

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

func _launch_track(track: Main.Track):
	if (!TRACK_SCENES.has(track)):
		push_error("Track {0} does not exist.".format([track]))
		return
	
	_clear_gui()
	_show_loading_screen()
	_trackToLoad = track
	_awaitingTrackToLoadSince = Time.get_ticks_msec()
	_awaitingTrackToLoad = true
	
	# if not deferred to process, the game freezes before the loading screen shows up.
	
func _show_loading_screen():
	$LoadingScreen.visible = true
	
func _hide_loading_screen():
	$LoadingScreen.visible = false

func _process(delta: float) -> void:
	var awaitingTrackTimeDiff: float = Time.get_ticks_msec() - _awaitingTrackToLoadSince
	if _awaitingTrackToLoad && awaitingTrackTimeDiff > TRACK_LOAD_DELAY_MS:
		assert(_trackToLoad != Track.NONE, "no track to load.")
		_clear_world()
		var trackScene: Track = TRACK_SCENES.get(_trackToLoad).instantiate()
		$World.add_child(trackScene)
		trackScene.launch(_selectedMode, _selectedSpeed)
		_hide_loading_screen()
		_awaitingTrackToLoad = false
