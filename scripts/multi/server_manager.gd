# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ServerManager extends Node

var max_players := 24

func start_server(port: int):
	var network: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	network.create_server(port, max_players)
	
	multiplayer.multiplayer_peer = network
	
	print("starting server on port %d." % [port])
