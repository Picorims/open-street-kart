# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name Main extends Node3D

const _3D_MENU_BACKGROUND: PackedScene = preload("res://scenes/backgrounds/gui_background_menus.tscn")
const _3D_MENU_BACKGROUND_V2: PackedScene = preload("res://scenes/backgrounds/gui_background_menus_v2.tscn")

const _SERVER_MANAGER = preload("res://server/server_manager.tscn")

const _SCREEN_PICK_MODE: PackedScene = preload("res://gui/screens/pick_mode_screen.tscn")
const _SCREEN_PICK_SPEED: PackedScene = preload("res://gui/screens/pick_speed_screen.tscn")
const _SCREEN_PICK_TRACK: PackedScene = preload("res://gui/screens/pick_track_screen.tscn")
const _SCREEN_CREDITS: PackedScene = preload("res://gui/screens/credits_screen.tscn")
const _SCREEN_HOME: PackedScene = preload("res://gui/screens/home_screen.tscn")
const _SCREEN_CREATE_OR_JOIN_SERV: PackedScene = preload("res://gui/screens/pick_serv_mode_screen.tscn")
const _SCREEN_JOIN_SERV: PackedScene = preload("res://gui/screens/join_serv_screen.tscn")
const _SCREEN_CREATE_SERV: PackedScene = preload("res://gui/screens/create_serv_screen.tscn")
const _SCREEN_LOBBY: PackedScene = preload("res://gui/screens/lobby_screen.tscn")
const _SCREEN_MP_GAME_CONFIG: PackedScene = preload("res://gui/screens/configure_mp_game_screen.tscn")

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
	LOBBY,
	CONFIGURE_MP_GAME
}

enum Track {
	NONE,
	ORSAY_HILLS,
}

const TRACK_SCENES: Dictionary[Main.Track, PackedScene] = {
	Track.ORSAY_HILLS: preload("res://scenes/races/orsay.tscn")
}

var _server_manager: ServerManager = null
@onready var _client_manager: ClientManager = $ServerInterface/ClientManager
@onready var _server_interface: Node = $ServerInterface

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
	#_apply_background(_BackgroundKind.MENU_BACKGROUND_3D)
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
				_apply_screen(_Screen.PICK_TRACK, {"multi": false, "is_host": true})
			)
			
			
		if (screen_kind == _Screen.PICK_TRACK):
			assert(settings.has("is_host"), "Screen.PICK_TRACK: is_host not defined.")
			assert(settings.has("multi"), "Screen.PICK_TRACK: multi not defined.")
			print("opening pick track screen")
			var is_host: bool = settings.get("is_host")
			var multi: bool = settings.get("multi")
			_clear_gui()
			var new_screen: PickTrackScreen = _SCREEN_PICK_TRACK.instantiate()
			$GUI.add_child(new_screen)
			
			# TODO handling of read-only multi clients.
			if not multi or is_host:
				new_screen.track_selected.connect(func(track: Main.Track):
					if not multi:
						push_error("TODO restore singleplayer")
					else:
						print("TODO launch track multi")
						#_launch_track(track)
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
			
			# If the screen was opened before, remove its signal connections.
			_client_manager.clear_signals()
			var client_rpc := _client_manager.get_rpc()
			
			_client_manager.client_ready.connect(func():
				client_rpc.c2s_set_username(new_screen.get_username())
				new_screen.set_status_message("Waiting for validation...")
			)
			_client_manager.connection_failed.connect(func():
				new_screen.set_status_message("Connection failed.")
			)
			_client_manager.disconnected.connect(func():
				new_screen.set_status_message("Unexpectedly disconnected from server.")
			)
			client_rpc.c_on_username_accepted.connect(func():
				_apply_screen(_Screen.LOBBY, {"is_host": false})
			)
			client_rpc.c_on_username_refused.connect(func():
				new_screen.set_status_message("Username refused, please try again.")
			)
			new_screen.join.connect(func(address, port, password):
				var error = _create_client(address, port, password)
				if error:
					if error == Error.ERR_ALREADY_IN_USE:
						new_screen.set_status_message("Could not spawn client, peer already in use.")
					elif error == Error.ERR_CANT_CREATE:
						new_screen.set_status_message("Could not spawn client, creation issue.")
					else:
						new_screen.set_status_message("Could not spawn client, unknown issue (%d)." % [error])
					return
				new_screen.set_status_message("Connecting...")
			)
			new_screen.back.connect(func():
				_apply_screen(_Screen.JOIN_OR_CREATE_SERV)
			)
			
			
		if (screen_kind == _Screen.CREATE_SERV):
			print("opening create server screen")
			_clear_gui()
			var new_screen: CreateServScreen = _SCREEN_CREATE_SERV.instantiate()
			$GUI.add_child(new_screen)
			
			# If the screen was opened before, remove its signal connections.
			_client_manager.clear_signals()
			var client_rpc := _client_manager.get_rpc()

			_client_manager.client_ready.connect(func():
				client_rpc.c2s_set_username(new_screen.get_username())
				new_screen.set_status_message("Waiting for validation...")
			)
			_client_manager.connection_failed.connect(func():
				new_screen.set_status_message("Connection failed.")
			)
			_client_manager.disconnected.connect(func():
				new_screen.set_status_message("Unexpectedly disconnected from server.")
			)
			client_rpc.c_on_username_accepted.connect(func():
				_apply_screen(_Screen.LOBBY, {"is_host": true})
			)
			client_rpc.c_on_username_refused.connect(func():
				new_screen.set_status_message("Username refused, please try again.")
			)

			new_screen.create.connect(func(port, password):
				new_screen.set_status_message("Spawning server...")
				var error = _create_server(port, password)
				if error:
					if error == Error.ERR_ALREADY_IN_USE:
						new_screen.set_status_message("Could not spawn server, peer already in use.")
					elif error == Error.ERR_CANT_CREATE:
						new_screen.set_status_message("Could not spawn server, creation issue.")
					else:
						new_screen.set_status_message("Could not spawn server, unknown issue (%d)." % [error])
					return
				
				
				error = _create_client("127.0.0.1", port, password)
				if error:
					if error == Error.ERR_ALREADY_IN_USE:
						new_screen.set_status_message("Could not spawn client, peer already in use.")
					elif error == Error.ERR_CANT_CREATE:
						new_screen.set_status_message("Could not spawn client, creation issue.")
					else:
						new_screen.set_status_message("Could not spawn client, unknown issue (%d)." % [error])
					return
				
				_server_manager.client_authority = _client_manager.get_peer_id()
				
				new_screen.set_status_message("Connecting locally...")
			)
			new_screen.back.connect(func():
				_apply_screen(_Screen.JOIN_OR_CREATE_SERV)
			)
			
			
		if (screen_kind == _Screen.LOBBY):
			print("opening lobby screen")
			_clear_gui()
			var new_screen: LobbyScreen = _SCREEN_LOBBY.instantiate()
			$GUI.add_child(new_screen)
			var is_host: bool = settings.get("is_host")
			new_screen.is_host = is_host
			if is_host:
				new_screen.launch.connect(func():
					_client_manager.get_rpc().c2s_request_launch()
				)
			new_screen.quit.connect(func():
				_disconnect_or_close_server(is_host)
				_apply_screen(_Screen.JOIN_OR_CREATE_SERV)
			)
			_client_manager.get_rpc().c_on_acknowledge_launch.connect(func(_id: int):
				_apply_screen(_Screen.CONFIGURE_MP_GAME, settings)
			)
		
		
		if (screen_kind == _Screen.CONFIGURE_MP_GAME):
			assert(settings.has("is_host"), "missing is_host setting for CONFIGURE_MP_GAME screen.")
			var is_host = settings.get("is_host")
			print("opening mp configuration screen. is_host: %s" % [is_host])
			_clear_gui()
			var new_screen: ConfigureMPGameScreen = _SCREEN_MP_GAME_CONFIG.instantiate()
			new_screen.is_host = settings.get("is_host")
			$GUI.add_child(new_screen)
			if is_host:
				new_screen.speed_picker_changed.connect(func(selected):
					print("send speed id %d" % [selected])
					_client_manager.get_rpc().c2s_speed_picker_changed(selected)
					pass
				)
				new_screen.cars_count_picker_changed.connect(func(selected):
					print("send cars count id %d" % [selected])
					_client_manager.get_rpc().c2s_cars_count_picker_changed(selected)
					pass
				)
				new_screen.confirm.connect(func(speed, cars_count):
					_client_manager.get_rpc().c2s_confirm_mp_config(speed, cars_count)
					_apply_screen(_Screen.PICK_TRACK, {"multi": true, "is_host": is_host})
				)
			else:
				_client_manager.get_rpc().c_on_speed_picker_changed.connect(func(selected):
					print("receive speed id %d" % [selected])
					new_screen.set_speed_selected(selected)
					pass
				)
				_client_manager.get_rpc().c_on_cars_count_picker_changed.connect(func(selected):
					print("receive cars count id %d" % [selected])
					new_screen.set_cars_count_selected(selected)
					pass
				)
				_client_manager.get_rpc().c_on_mp_config_confirmed.connect(func():
					_apply_screen(_Screen.PICK_TRACK, {"multi": true, "is_host": is_host})
				)

func _create_server(port: int, _password: String) -> Error:
	
	if _server_manager != null:
		_server_interface.remove_child(_server_manager)
		_server_manager.queue_free()
	_server_manager = _SERVER_MANAGER.instantiate()
	_server_interface.add_child(_server_manager)
	var error := _server_manager.start_server(port)
	return error

func _create_client(address: String, port: int, _password: String) -> Error:
	var error = _client_manager.connect_to_server(address, port)
	return error

func _disconnect_or_close_server(is_host: bool):
	if is_host:
		_client_manager.disconnect_from_server()
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
