# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name KartSync extends Node

signal network_id_updated
signal mode_updated

@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

@export var mode: Global.KartMode = Global.KartMode.UNSET
@export var network_id := -1
@export var display_name: String = ""
@export var kart_color: Color = Color.BLACK

func _ready() -> void:
	multiplayer_synchronizer.synchronized.connect(func():
		network_id_updated.emit()
		mode_updated.emit()
	)
	multiplayer_synchronizer.delta_synchronized.connect(func():
		network_id_updated.emit()
		mode_updated.emit()
	)
