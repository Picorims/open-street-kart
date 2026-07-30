# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PickServModeScreen extends CenterContainer

signal join_server
signal create_server
signal back

@onready var join_server_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/ButtonsVBoxContainer/JoinServerButton
@onready var create_server_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/ButtonsVBoxContainer/CreateServerButton
@onready var back_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/ButtonsVBoxContainer/BackButton


func _ready() -> void:
	ButtonSignalEntry.link_signals([
		ButtonSignalEntry.new(join_server_button, join_server),
		ButtonSignalEntry.new(create_server_button, create_server),
		ButtonSignalEntry.new(back_button, back),
	])
