# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ClientDataManager extends Node

signal on_player_list_changed

## Not synced automatically, managed per client.
## Listen to RPC calls to update the dictionary.
var _players: Dictionary[int, String] = {}

func get_players():
	return _players

func set_players(list: Dictionary[int, String]):
	_players = list
	on_player_list_changed.emit()
