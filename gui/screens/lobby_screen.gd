# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name LobbyScreen extends CenterContainer

signal launch
signal quit

@onready var _launch_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/LaunchButton
@onready var _quit_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/QuitButton
@onready var _players: VBoxContainer = $UIBlockContainer/Players

var is_host := false:
	set(v):
		is_host = v
		_launch_button.disabled = not is_host

func _ready() -> void:
	ButtonSignalEntry.link_signals([
		ButtonSignalEntry.new(_launch_button, launch),
		ButtonSignalEntry.new(_quit_button, quit),
	])
	refresh_player_list()
	s_client_data_manager.on_player_list_changed.connect(refresh_player_list)
	_quit_button.grab_focus()
	
func refresh_player_list():
	var list: Dictionary[int, String] = s_client_data_manager.get_players()
	print("lobby: applying list ", list)
	for child in _players.get_children():
		child.queue_free()
	for peer_id in list:
		var username := list[peer_id]
		var label := Label.new()
		label.text = username
		_players.add_child(label)
