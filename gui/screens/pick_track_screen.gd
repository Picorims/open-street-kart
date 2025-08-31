# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PickTrackScreen extends Control

signal track_selected(mode: Main.Track)

func _ready() -> void:
	pass
	#_connect_button_to_mode(
		#$UIBlockContainer/ButtonsVBoxContainer/AtomGUIBlurredBgndMenuButton_Chill,
		#"chill",
		#TrackState.SpeedMode.CHILL
	#)
	#
	#_connect_button_to_mode(
		#$UIBlockContainer/ButtonsVBoxContainer/AtomGUIBlurredBgndMenuButton_Casual,
		#"casual",
		#TrackState.SpeedMode.CASUAL
	#)
	#
	#_connect_button_to_mode(
		#$UIBlockContainer/ButtonsVBoxContainer/AtomGUIBlurredBgndMenuButton_Challenging,
		#"challenging",
		#TrackState.SpeedMode.CHALLENGING
	#)
	#
	#_connect_button_to_mode(
		#$UIBlockContainer/ButtonsVBoxContainer/AtomGUIBlurredBgndMenuButton_Crazy,
		#"crazy",
		#TrackState.SpeedMode.CRAZY
	#)

#func _connect_button_to_mode(node: AtomGUIBlurredBgndMenuButton, name: String, mode: TrackState.SpeedMode):
	#assert(node != null, "{0} button undefined.".format([name]))
	#node.pressed.connect(func():
		#mode_selected.emit(mode)
	#)
