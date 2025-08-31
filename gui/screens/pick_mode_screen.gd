# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PickModeScreen extends CenterContainer

signal mode_selected(mode: TrackState.GameMode)

func _ready() -> void:
	var againstClockButton = $UIBlockContainer/ButtonsVBoxContainer/AtomGUIBlurredBgndMenuButton_AgainstClock
	assert(againstClockButton != null, "against clock button undefined.")
	againstClockButton.pressed.connect(func():
		mode_selected.emit(TrackState.GameMode.AGAINST_CLOCK)
	)
	
	var versusButton = $UIBlockContainer/ButtonsVBoxContainer/AtomGUIBlurredBgndMenuButton_Versus
	assert(againstClockButton != null, "versus button undefined.")
	versusButton.pressed.connect(func():
		mode_selected.emit(TrackState.GameMode.VERSUS)
	)
