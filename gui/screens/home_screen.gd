# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name HomeScreen extends Control

signal play_single
signal play_multi
signal open_credits
signal quit

@onready var play_single_button: AtomGUIBlurredBgndMenuButton = $VBoxContainer/VBoxContainer/PlaySingleButton
@onready var play_multi_button: AtomGUIBlurredBgndMenuButton = $VBoxContainer/VBoxContainer/PlayMultiButton
@onready var credits_button: AtomGUIBlurredBgndMenuButton = $VBoxContainer/VBoxContainer/CreditsButton
@onready var quit_button: AtomGUIBlurredBgndMenuButton = $VBoxContainer/VBoxContainer/QuitButton


func _ready() -> void:
	ButtonSignalEntry.link_signals([
		ButtonSignalEntry.new(play_single_button, play_single),
		ButtonSignalEntry.new(play_multi_button, play_multi),
		ButtonSignalEntry.new(credits_button, open_credits),
		ButtonSignalEntry.new(quit_button, quit),
	])
	play_single_button.grab_focus()
