# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RPC extends Node

signal c_on_username_accepted(id: int)
signal c_on_username_refused(id: int)


var _valid_username := RegEx.create_from_string("[a-zA-Z0-9_]{3,32}")
var server_manager: ServerManager = null

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





func c2s_set_username(username: String):
	_set_username.rpc_id(1, username)

func s2c_broadcast_players_list(list: Dictionary[int, String]):
	_broadcast_player_list.rpc(list)



func clear_signals():
	SignalUtils.clear_connections_from_signal(c_on_username_accepted)
	SignalUtils.clear_connections_from_signal(c_on_username_refused)
