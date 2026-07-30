# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name LobbyScreen extends CenterContainer

signal launch
signal quit

@onready var launch_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/LaunchButton
@onready var quit_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/QuitButton

var is_host := false:
	set(v):
		is_host = v
		launch_button.disabled = not is_host

func _ready() -> void:
	ButtonSignalEntry.link_signals([
		ButtonSignalEntry.new(launch_button, launch),
		ButtonSignalEntry.new(quit_button, quit),
	])
