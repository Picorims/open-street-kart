# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name AtomGUIRaceRankingLine extends Control

@export var position_str: String:
	set(v):
		position_str = v
		$MarginContainer/position.text = v

@export var name_str: String:
	set(v):
		name_str = v
		$MarginContainer/name.text = v

@export var time_str: String:
	set(v):
		time_str = v
		$MarginContainer/time.text = v
