# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RPC extends Node

signal c_on_username_accepted(id: int)
signal c_on_username_refused(id: int)
signal c_on_acknowledge_launch(id: int)
signal c_on_speed_picker_changed(selected: int)
signal c_on_cars_count_picker_changed(selected: int)
signal c_on_mp_config_confirmed()
signal c_on_track_launch(track: Main.TrackId, speed_mode: TrackStateModel.SpeedMode, cars_count: int, game_mode: TrackStateModel.GameMode)


var _valid_username := RegEx.create_from_string("[a-zA-Z0-9_]{3,32}")
var server_manager: ServerManager = null

func _is_client_authority(peer: int) -> bool:
	return server_manager.client_authority == peer

func _is_server(peer: int) -> bool:
	return peer == 1

func _from_host_to_serv() -> bool:
	if not _is_server(multiplayer.get_unique_id()):
		return false
	if not _is_client_authority(multiplayer.get_remote_sender_id()):
		return false
	return true

## client -> server: register username
@rpc("any_peer", "call_remote", "reliable")
func _set_username(username: String):
	var caller_id := multiplayer.get_remote_sender_id()
	print("server: receiving username from %d" % [caller_id])
	if multiplayer.get_unique_id() != 1:
		return
	var valid := _valid_username.search(username)
	if valid == null:
		_set_username_refused.rpc_id(caller_id)
	else:
		server_manager.players.set(caller_id, username)
		_set_username_accepted.rpc_id(caller_id)
		_broadcast_player_list.rpc(server_manager.players)

## server -> client[id]: inform about an ignored username (refusing lobby entry).
@rpc("authority", "call_remote", "reliable")
func _set_username_refused():
	c_on_username_refused.emit()

## server -> client[id]: inform about an accepted username (accepting lobby entry).
@rpc("authority", "call_remote", "reliable")
func _set_username_accepted():
	c_on_username_accepted.emit()

## server -> client[broadcast]: update all peers player list
@rpc("authority", "call_remote", "reliable")
func _broadcast_player_list(list: Dictionary[int, String]):
	var id = multiplayer.get_unique_id()
	print("client %d: receiving updated players list." % [id])
	s_client_data_manager.set_players(list)

## client[host] -> server: request launch, leading to configuring the game
@rpc("any_peer", "call_remote", "reliable")
func _request_launch():
	if multiplayer.get_unique_id() != 1:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != server_manager.client_authority:
		return
	_acknowledge_launch.rpc()

## server -> client[broadcast] confirm launch, leading to game config.
@rpc("authority", "call_remote", "reliable")
func _acknowledge_launch():
	if multiplayer.get_unique_id() == 1:
		return
	c_on_acknowledge_launch.emit(multiplayer.get_unique_id())

## client[host] -> server: speed picker UI sync to guest clients
@rpc("any_peer", "call_remote", "reliable")
func _speed_picker_changed(selected: int):
	if multiplayer.get_unique_id() != 1:
		return
	if not _is_client_authority(multiplayer.get_remote_sender_id()):
		return
	print("server: broadcasting speed changed")
	_broadcast_speed_picker_changed.rpc(selected)

## server -> client[broadcast]: speed picker UI sync to guest clients
@rpc("authority", "call_remote", "reliable")
func _broadcast_speed_picker_changed(selected: int):
	var id := multiplayer.get_unique_id()
	c_on_speed_picker_changed.emit(selected)

@rpc("any_peer", "call_remote", "reliable")
func _cars_count_picker_changed(selected: int):
	if multiplayer.get_unique_id() != 1:
		return
	if not _is_client_authority(multiplayer.get_remote_sender_id()):
		return
	print("server: broadcasting cars count changed")
	_broadcast_cars_count_picker_changed.rpc(selected)

## server -> client[broadcast]: speed picker UI sync to guest clients
@rpc("authority", "call_remote", "reliable")
func _broadcast_cars_count_picker_changed(selected: int):
	var id := multiplayer.get_unique_id()
	c_on_cars_count_picker_changed.emit(selected)

## client[host] -> server: submit mp game config
@rpc("any_peer", "call_remote", "reliable")
func _confirm_mp_config(speed: TrackStateModel.SpeedMode, cars_count: int):
	if not _is_server(multiplayer.get_unique_id()):
		return
	if not _is_client_authority(multiplayer.get_remote_sender_id()):
		return
	server_manager.speed_mode = speed
	server_manager.cars_count = cars_count
	_acknowledge_confirm_mp_config.rpc()

## server -> client[broadcast]: acknowledge mp config
## is received and applied server-side.
@rpc("authority", "call_remote", "reliable")
func _acknowledge_confirm_mp_config():
	c_on_mp_config_confirmed.emit()

## client[host] -> server
@rpc("any_peer", "call_remote", "reliable")
func _launch_track(track: Main.TrackId):
	if not _from_host_to_serv():
		return
	_broadcast_launch_track.rpc(track, server_manager.speed_mode, server_manager.cars_count, TrackStateModel.GameMode.VERSUS)
	
@rpc("authority", "call_remote", "reliable")
func _broadcast_launch_track(track: Main.TrackId, speed_mode: TrackStateModel.SpeedMode, cars_count: int, game_mode: TrackStateModel.GameMode):
	c_on_track_launch.emit(track, speed_mode, cars_count, game_mode)
	
	




func c2s_set_username(username: String):
	_set_username.rpc_id(1, username)

func s2c_broadcast_players_list(list: Dictionary[int, String]):
	_broadcast_player_list.rpc(list)

func c2s_request_launch():
	_request_launch.rpc_id(1)

func c2s_speed_picker_changed(selected: int):
	_speed_picker_changed.rpc_id(1, selected)

func c2s_cars_count_picker_changed(selected: int):
	_cars_count_picker_changed.rpc_id(1, selected)

func c2s_confirm_mp_config(speed: TrackStateModel.SpeedMode, cars_count: int):
	_confirm_mp_config.rpc_id(1, speed, cars_count)

func c2s_launch_track(track: Main.TrackId):
	_launch_track.rpc_id(1, track)

func clear_signals():
	SignalUtils.clear_connections_from_signal(c_on_username_accepted)
	SignalUtils.clear_connections_from_signal(c_on_username_refused)
