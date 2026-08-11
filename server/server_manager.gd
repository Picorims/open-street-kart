# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Multiplayer authority. It is NOT a player.
class_name ServerManager extends Node

var max_players := 24
var players: Dictionary[int, String] = {}
var _mp: MultiplayerAPI
@onready var _server_rpc: RPC = $RPC


func start_server(port: int) -> Error:
	var network: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = network.create_server(port, max_players)
	if error:
		return error
	multiplayer.multiplayer_peer = network
	_server_rpc.multiplayer.multiplayer_peer = network
	print("starting server on port %d." % [port])
	return Error.OK

func _on_player_connected(id: int):
	print("Peer %d connected" % [id])

func _on_player_disconnected(id: int):
	var username = players.get(id)
	players.erase(id)
	_server_rpc.s2c_broadcast_players_list(players)
	print("Peer %d disconnected (was %s)" % [id, username])

func close_server():
	close_peer_connection()
	print("Server closed.")

func close_peer_connection():
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_server_rpc.multiplayer.multiplayer_peer = multiplayer.multiplayer_peer

func _ready() -> void:
	_mp = SceneMultiplayer.new()
	_mp.root_path = _server_rpc.get_path()
	get_tree().set_multiplayer(_mp, get_path())

	# https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#managing-connections
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	_server_rpc.server_manager = self
