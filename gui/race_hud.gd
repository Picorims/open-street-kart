# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RaceHUD extends Control

const CURSOR_HUD: PackedScene = preload("res://gui/atoms/atom_hud_race_player_pos.tscn")

@export var cursorsHolder: Control

var _cursors: Dictionary[String, AtomHUDRacePlayerPos] = {}

class RatioEntry:
	var ratio: float
	var color: Color

func _ready() -> void:
	assert(cursorsHolder.has_node("GroupPosition"), "ERROR: Missing GroupPosition in cursorsHolder")

func display_ratios(ratios: Dictionary[String, RatioEntry]) -> void:
	for k in ratios.keys():
		var cursor: AtomHUDRacePlayerPos = null
		if _cursors.has(k):
			cursor = _cursors.get(k)
		else:
			cursor = CURSOR_HUD.instantiate()
			cursor.label = k
			cursor.color = ratios[k].color
			cursor.emphasis = k == "you" #FIXME proper system once naming spec is in place
			cursorsHolder.add_child(cursor)
			_cursors.set(k, cursor)
		cursor.set_position(Vector2((ratios[k].ratio * cursorsHolder.size.x) - (cursor.size.x / 2), - cursor.size.y + cursorsHolder.size.y), true)

func update_group_pos(ratioFrom: float, ratioTo: float):
	DebugDraw2D.set_text("ratioFrom", ratioFrom)
	DebugDraw2D.set_text("ratioTo", ratioTo)
	
	var bar: ColorRect = cursorsHolder.get_node("GroupPosition")
	bar.set_position(Vector2(ratioFrom * cursorsHolder.size.x, bar.position.y), true)
	bar.set_size(Vector2((ratioTo - ratioFrom) * cursorsHolder.size.x, bar.size.y), true)
