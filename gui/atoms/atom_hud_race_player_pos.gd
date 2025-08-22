# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name AtomHUDRacePlayerPos extends Control

@export var label: String:
	set(v):
		label = v
		$MarginContainer/name.text = v

@export var color: Color:
	set(v):
		color = v
		$ColorRect.color = v

@export var emphasis: bool = false:
	set(v):
		var arrowSettings: LabelSettings = $MarginContainer/arrow.label_settings
		var nameSettings: LabelSettings = $MarginContainer/name.label_settings
		emphasis = v
		if (emphasis):
			arrowSettings.font_color = Color(1,0.5,0.5)
			arrowSettings.font_size = 12
			nameSettings.font_color = Color(1,0.5,0.5)
			nameSettings.font_size = 16
			nameSettings.outline_size = 4
		else:
			arrowSettings.font_color = Color(1,1,1)
			arrowSettings.font_size = 8
			nameSettings.font_color = Color(1,1,1)
			nameSettings.font_size = 12
			nameSettings.outline_size = 2
