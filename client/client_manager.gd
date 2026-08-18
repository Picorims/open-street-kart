# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ClientManager extends Node

signal client_ready
signal connection_failed
signal disconnected

var _mp: MultiplayerAPI
@onready var _client_rpc: RPC = $RPC

func get_rpc() -> RPC:
	return _client_rpc

func connect_to_server(host_ip: String, port: int) -> Error:
	var network: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = network.create_client(host_ip, port)
	if error:
		return error
	
	multiplayer.multiplayer_peer = network
	_client_rpc.multiplayer.multiplayer_peer = network
	
	print("Connecting to %s:%d" % [host_ip, port])
	return Error.OK

func _on_connected_to_server():
	print("Connected to server!")
	client_ready.emit()

func _on_connection_failed():
	close_peer_connection()
	print("Connection to server failed.")
	connection_failed.emit()

func _on_disconnected_from_server():
	close_peer_connection()
	print("Forcefully disconnected from server.")
	disconnected.emit()

func disconnect_from_server():
	multiplayer.multiplayer_peer.close()
	close_peer_connection()
	print("Intentionally disconnected from server.")

func close_peer_connection():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_client_rpc.multiplayer.multiplayer_peer = multiplayer.multiplayer_peer
	
func _ready() -> void:
	_mp = SceneMultiplayer.new()
	_mp.root_path = _client_rpc.get_path()
	get_tree().set_multiplayer(_mp, get_path())

	# https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#managing-connections
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected_from_server)

func clear_signals():
	SignalUtils.clear_connections_from_signal(client_ready)
	SignalUtils.clear_connections_from_signal(connection_failed)
	SignalUtils.clear_connections_from_signal(disconnected)
	_client_rpc.clear_signals()

func get_peer_id() -> int:
	return multiplayer.get_unique_id()
