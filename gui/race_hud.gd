# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name RaceHUD extends Control

const CURSOR_HUD: PackedScene = preload("res://gui/atoms/atom_hud_race_player_pos.tscn")

@export var cursors_holder: Control

var _cursors: Dictionary[String, AtomHUDRacePlayerPos] = {}
var _item_slots: Array[AtomHUDRaceItemSlot] = []

class RatioEntry:
	var ratio: float
	var color: Color

func _ready() -> void:
	assert(cursors_holder.has_node("GroupPosition"), "ERROR: Missing GroupPosition in cursors_holder")
	_item_slots = [
		$ItemSlotsContainer/ItemSlotsHorizontalLayout/AtomHUDRaceItemSlot,
		$ItemSlotsContainer/ItemSlotsHorizontalLayout/AtomHUDRaceItemSlot2,
		$ItemSlotsContainer/ItemSlotsHorizontalLayout/AtomHUDRaceItemSlot3
	]

	for control in _item_slots:
		assert(control != null, "item slot not found in race HUD.")
func display_ratios(ratios: Dictionary[String, RatioEntry]) -> void:
	for k in ratios.keys():
		var cursor: AtomHUDRacePlayerPos = null
		if _cursors.has(k):
			cursor = _cursors.get(k)
		else:
			cursor = CURSOR_HUD.instantiate()
			cursor.label = k
			cursor.color = ratios[k].color
			cursor.emphasis = k == "you" # FIXME proper system once naming spec is in place
			cursors_holder.add_child(cursor)
			_cursors.set(k, cursor)
		cursor.set_position(Vector2((ratios[k].ratio * cursors_holder.size.x) - (cursor.size.x / 2), -cursor.size.y + cursors_holder.size.y), true)

func update_group_pos(ratio_from: float, ratio_to: float):
	DebugDraw2D.set_text("ratio_from", ratio_from)
	DebugDraw2D.set_text("ratio_to", ratio_to)
	
	var bar: ColorRect = cursors_holder.get_node("GroupPosition")
	bar.set_position(Vector2(ratio_from * cursors_holder.size.x, bar.position.y), true)
	bar.set_size(Vector2((ratio_to - ratio_from) * cursors_holder.size.x, bar.size.y), true)

func set_self_ranking(ranking: int) -> void:
	$SelfRankingContainer/SelfRanking.text = "{0}".format([ranking])

func update_item_slots_hud(state: Array[PlayerItemSlotsState.SlotDisplayState]) -> void:
	assert(state.size() == 3, "unexpected slot length (did the constant change?)")
	
	for i in range(_item_slots.size()):
		_item_slots[i].set_item(state[i].item)
		var ratio: float = state[i].progress_ratio
		if state[i].item != PlayerItemSlotsState.SlotItem.EMPTY and state[i].item != PlayerItemSlotsState.SlotItem.DISABLED:
			ratio = 1 - ratio # flip direction
		_item_slots[i].set_progress_ratio(ratio)
		
