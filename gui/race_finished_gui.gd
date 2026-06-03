# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name RaceFinishedGUI extends Control

const ATOM_GUI_RACE_RANKING_LINE_SCENE: PackedScene = preload("res://gui/atoms/atom_gui_race_ranking_line.tscn")

func append_line(rank_position: String, player_name: String, time: String) -> void:
	var line: AtomGUIRaceRankingLine = ATOM_GUI_RACE_RANKING_LINE_SCENE.instantiate()
	line.name_str = player_name
	line.position_str = rank_position
	line.time_str = time
	$MainContainer/VBoxContainer.add_child(line)
