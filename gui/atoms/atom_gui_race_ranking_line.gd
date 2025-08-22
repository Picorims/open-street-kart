# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name AtomGUIRaceRankingLine extends Control

@export var positionStr: String:
	set(v):
		positionStr = v
		$MarginContainer/position.text = v

@export var nameStr: String:
	set(v):
		nameStr = v
		$MarginContainer/name.text = v

@export var timeStr: String:
	set(v):
		timeStr = v
		$MarginContainer/time.text = v
