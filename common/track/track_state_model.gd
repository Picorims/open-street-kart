# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TrackStateModel extends Node

@export var mode: GameMode
@export var speed: SpeedMode
@export var started = false
@export var start_us: float = 0
## IDs and car names are equivalent
@export var ids: Array[String] = []
@export var start_lap_us: Dictionary[String, float]
@export var durations_us: Dictionary[String, Array] # is Array[float]
## stored in order of reaching finish line
@export var total_us: Dictionary[String, float]
@export var display_names: Dictionary[String, String]
var car_item_slots: Dictionary[String, PlayerItemSlotsState]
@export var car_item_slots_state: Dictionary[String, PlayerItemSlotsState] = {}

@export var last_estimated_rankings: TrackOffsetEntries = TrackOffsetEntries.new()
@export var final_rankings: TrackFinalRankingEntries = TrackFinalRankingEntries.new()
@export var race_finished: bool = false

@export var in_countdown: bool = false
@export var countdown_state: CountdownStateMachine.CountdownState = CountdownStateMachine.CountdownState.IDLE


enum GameMode {
	AGAINST_CLOCK,
	VERSUS
}

enum SpeedMode {
	CHILL,
	CASUAL,
	CHALLENGING,
	CRAZY
}

const TrackSpeedDict: Dictionary[SpeedMode, float] = {
	SpeedMode.CHILL: 25,
	SpeedMode.CASUAL: 30,
	SpeedMode.CHALLENGING: 35,
	SpeedMode.CRAZY: 40,
}
const OutOfBoundsSpeedDict: Dictionary[SpeedMode, float] = {
	SpeedMode.CHILL: 6,
	SpeedMode.CASUAL: 8,
	SpeedMode.CHALLENGING: 9,
	SpeedMode.CRAZY: 11,
}
