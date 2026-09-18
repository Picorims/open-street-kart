# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name KartRemote extends Node

@export var client: ClientManager

func _enter_tree() -> void:
	assert(client != null, "kart remote: missing client.")

func _unhandled_input(event: InputEvent) -> void:
	var rpc: RPC = client.get_rpc()
	if event.is_action("drift"):
		rpc.c2s_send_input_bool(RPC.InputEventBoolType.DRIFT, event.is_pressed())
	elif event.is_action("forward") or event.is_action("backward"):
		rpc.c2s_send_input_float(RPC.InputEventFloatType.BACKWARD_FORWARD, Input.get_axis("backward", "forward"))
	elif event.is_action("left") or event.is_action("right"):
		rpc.c2s_send_input_float(RPC.InputEventFloatType.LEFT_RIGHT, Input.get_axis("left", "right"))
