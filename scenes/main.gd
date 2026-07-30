# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name Main extends Node3D

const _3D_MENU_BACKGROUND: PackedScene = preload("res://scenes/backgrounds/gui_background_menus.tscn")
const _3D_MENU_BACKGROUND_V2: PackedScene = preload("res://scenes/backgrounds/gui_background_menus_v2.tscn")

const _SCREEN_PICK_MODE: PackedScene = preload("res://gui/screens/pick_mode_screen.tscn")
const _SCREEN_PICK_SPEED: PackedScene = preload("res://gui/screens/pick_speed_screen.tscn")
const _SCREEN_PICK_TRACK: PackedScene = preload("res://gui/screens/pick_track_screen.tscn")
const _SCREEN_CREDITS: PackedScene = preload("res://gui/screens/credits_screen.tscn")
const _SCREEN_HOME: PackedScene = preload("res://gui/screens/home_screen.tscn")
const _SCREEN_CREATE_OR_JOIN_SERV: PackedScene = preload("res://gui/screens/pick_serv_mode_screen.tscn")
const _SCREEN_JOIN_SERV: PackedScene = preload("res://gui/screens/join_serv_screen.tscn")
const _SCREEN_CREATE_SERV: PackedScene = preload("res://gui/screens/create_serv_screen.tscn")
const _LOBBY_SERV: PackedScene = preload("res://gui/screens/lobby_screen.tscn")

enum _BackgroundKind {
	UNSET,
	MENU_BACKGROUND_3D,
}

enum _Screen {
	NONE,
	CREDITS,
	HOME,
	PICK_MODE,
	PICK_SPEED,
	PICK_TRACK,
	JOIN_OR_CREATE_SERV,
	JOIN_SERV,
	CREATE_SERV,
	LOBBY
}

enum Track {
	NONE,
	ORSAY_HILLS,
}

const TRACK_SCENES: Dictionary[Main.Track, PackedScene] = {
	Track.ORSAY_HILLS: preload("res://scenes/races/orsay.tscn")
}

@onready var _server_manager: ServerManager = $ServerInterface/ServerManager
@onready var _client_manager: ClientManager = $ServerInterface/ClientManager

var _current_background: _BackgroundKind = _BackgroundKind.UNSET
var _current_screen: _Screen = _Screen.NONE

var _selected_mode: TrackState.GameMode
var _selected_speed: TrackState.SpeedMode
var _track_to_load: Main.Track = Main.Track.NONE
var _awaiting_track_to_load: bool = false
var _awaiting_track_to_load_since: float = 0
const TRACK_LOAD_DELAY_MS = 100

func get_selected_mode() -> TrackState.GameMode:
	return _selected_mode

func get_selected_speed() -> TrackState.SpeedMode:
	return _selected_speed

func _ready():
	print("Loading...")
	#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DebugDraw2D.config.text_block_offset.y = 150
	_apply_background(_BackgroundKind.MENU_BACKGROUND_3D)
	_apply_screen(_Screen.HOME)
	print("Loading done.")

## If screen is different, apply it.
func _apply_screen(screen_kind: _Screen, settings: Dictionary[String, Variant] = {}):
	if (_current_screen != screen_kind):
		if (screen_kind == _Screen.PICK_MODE):
			print("opening pick mode screen")
			_clear_gui()
			var new_screen: PickModeScreen = _SCREEN_PICK_MODE.instantiate()
			$GUI.add_child(new_screen)
			new_screen.mode_selected.connect(func(mode: TrackState.GameMode):
				_selected_mode = mode
				_apply_screen(_Screen.PICK_SPEED)
			)
		if (screen_kind == _Screen.PICK_SPEED):
			print("opening pick speed screen")
			_clear_gui()
			var new_screen: PickSpeedScreen = _SCREEN_PICK_SPEED.instantiate()
			$GUI.add_child(new_screen)
			new_screen.mode_selected.connect(func(mode: TrackState.SpeedMode):
				_selected_speed = mode
				_apply_screen(_Screen.PICK_TRACK)
			)
		if (screen_kind == _Screen.PICK_TRACK):
			print("opening pick track screen")
			_clear_gui()
			var new_screen: PickTrackScreen = _SCREEN_PICK_TRACK.instantiate()
			$GUI.add_child(new_screen)
			new_screen.track_selected.connect(func(track: Main.Track):
				_launch_track(track)
			)
		if (screen_kind == _Screen.CREDITS):
			print("opening credits screen")
			_clear_gui()
			var new_screen: CreditsScreen = _SCREEN_CREDITS.instantiate()
			$GUI.add_child(new_screen)
			new_screen.back_requested.connect(func():
				_apply_screen(_Screen.HOME)
			)
		if (screen_kind == _Screen.HOME):
			print("opening home screen")
			_clear_gui()
			var new_screen: HomeScreen = _SCREEN_HOME.instantiate()
			$GUI.add_child(new_screen)
			new_screen.play_single.connect(func():
				_apply_screen(_Screen.PICK_MODE)
			)
			new_screen.play_multi.connect(func():
				_apply_screen(_Screen.JOIN_OR_CREATE_SERV)
			)
			new_screen.open_credits.connect(func():
				_apply_screen(_Screen.CREDITS)
			)
			new_screen.quit.connect(func():
				get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
				get_tree().quit()
			)
		if (screen_kind == _Screen.JOIN_OR_CREATE_SERV):
			print("opening join or create server screen")
			_clear_gui()
			var new_screen: PickServModeScreen = _SCREEN_CREATE_OR_JOIN_SERV.instantiate()
			$GUI.add_child(new_screen)
			new_screen.join_server.connect(func():
				_apply_screen(_Screen.JOIN_SERV)
			)
			new_screen.create_server.connect(func():
				_apply_screen(_Screen.CREATE_SERV)
			)
			new_screen.back.connect(func():
				_apply_screen(_Screen.HOME)
			)
		if (screen_kind == _Screen.JOIN_SERV):
			print("opening join server screen")
			_clear_gui()
			var new_screen: JoinServScreen = _SCREEN_JOIN_SERV.instantiate()
			$GUI.add_child(new_screen)
			new_screen.join.connect(func(address, port, username, password):
				_create_client(address, port, username, password)
				_apply_screen(_Screen.LOBBY, {"is_host": false})
			)
			new_screen.back.connect(func():
				_apply_screen(_Screen.JOIN_OR_CREATE_SERV)
			)
		if (screen_kind == _Screen.CREATE_SERV):
			print("opening create server screen")
			_clear_gui()
			var new_screen: CreateServScreen = _SCREEN_CREATE_SERV.instantiate()
			$GUI.add_child(new_screen)
			new_screen.create.connect(func(port, username, password):
				_create_server(port, username, password)
				_apply_screen(_Screen.LOBBY, {"is_host": true})
			)
			new_screen.back.connect(func():
				_apply_screen(_Screen.JOIN_OR_CREATE_SERV)
			)
		if (screen_kind == _Screen.LOBBY):
			print("opening lobby screen")
			_clear_gui()
			var new_screen: LobbyScreen = _LOBBY_SERV.instantiate()
			$GUI.add_child(new_screen)
			var is_host: bool = settings.get("is_host")
			new_screen.is_host = is_host
			new_screen.launch.connect(func(port, username, password):
				print('TODO launch')
			)
			new_screen.quit.connect(func():
				print("TODO quit")
				_disconnect_or_close_server(is_host)
				_apply_screen(_Screen.JOIN_OR_CREATE_SERV)
			)

func _create_server(port: int, username: String, password: String):
	_server_manager.start_server(port)

func _create_client(address: String, port: int, username: String, password: String):
	_client_manager.connect_to_server(address, port)

func _disconnect_or_close_server(is_host: bool):
	if is_host:
		_server_manager.close_server()
	else:
		_client_manager.disconnect_from_server()

## If background is different, apply it.
func _apply_background(background_kind: _BackgroundKind):
	if (_current_background != background_kind):
		if (background_kind == _BackgroundKind.MENU_BACKGROUND_3D):
			_clear_world()
			var env: Node3D = _3D_MENU_BACKGROUND_V2.instantiate()
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
	if (not TRACK_SCENES.has(track)):
		push_error("Track {0} does not exist.".format([track]))
		return
	
	_clear_gui()
	_show_loading_screen()
	_track_to_load = track
	_awaiting_track_to_load_since = Time.get_ticks_msec()
	_awaiting_track_to_load = true
	
	# if not deferred to process, the game freezes before the loading screen shows up.
	
func _show_loading_screen():
	$LoadingScreen.visible = true
	
func _hide_loading_screen():
	$LoadingScreen.visible = false

func _process(_delta: float) -> void:
	var awaiting_track_time_diff: float = Time.get_ticks_msec() - _awaiting_track_to_load_since
	if _awaiting_track_to_load and awaiting_track_time_diff > TRACK_LOAD_DELAY_MS:
		assert(_track_to_load != Track.NONE, "no track to load.")
		_clear_world()
		var track_scene: Track = TRACK_SCENES.get(_track_to_load).instantiate()
		$World.add_child(track_scene)
		track_scene.launch(_selected_mode, _selected_speed)
		_hide_loading_screen()
		_awaiting_track_to_load = false
