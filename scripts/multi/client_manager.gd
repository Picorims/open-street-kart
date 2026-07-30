# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ClientManager extends Node

func connect_to_server(host_ip: String, port: int):
	var network: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	network.create_client(host_ip, port)
	
	multiplayer.multiplayer_peer = network
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_disconnected_from_server)
	
	print("Connecting to %s:%d" % [host_ip, port])

func _on_connected_to_server():
	print("Connected to server!")

func _on_disconnected_from_server():
	print("Forcefully disconnected from server.")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func disconnect_from_server():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("Intentionally disconnected from server.")
