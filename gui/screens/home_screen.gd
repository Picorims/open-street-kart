# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name HomeScreen extends Control

signal play
signal open_credits
signal quit

func _ready() -> void:
	_connect_button_to_signal(
		$VBoxContainer/VBoxContainer/PlayButton,
		"play",
		play
	)
	
	_connect_button_to_signal(
		$VBoxContainer/VBoxContainer/CreditsButton,
		"credits",
		open_credits
	)
	
	_connect_button_to_signal(
		$VBoxContainer/VBoxContainer/QuitButton,
		"quit",
		quit
	)
	
func _connect_button_to_signal(node: AtomGUIBlurredBgndMenuButton, button_name: String, signal_ref: Signal):
	assert(node != null, "{0} button undefined.".format([button_name]))
	node.pressed.connect(func():
		signal_ref.emit()
	)
