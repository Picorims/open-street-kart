# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TrackStateModel extends Node

const CountdownState = CountdownStateMachine.CountdownState

signal in_countdown_changed(in_countdown: bool)
signal countdown_state_changed(state: CountdownState)
signal race_has_finished

@export var mode: GameMode = GameMode.UNSET
@export var speed: SpeedMode = SpeedMode.UNSET
@export var started: bool = false
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

# estimated rankings
## position on the track from the start based on the track path
@export var car_offsets: Dictionary[String, float] = {}
@export var colors: Dictionary[String, Color] = {}
@export var rankings: Dictionary[String, int] = {}

# final rankings
@export var final_times_or_distance: Dictionary[String, String] = {}
@export var final_rankings: Dictionary[String, int] = {}

@export var race_finished: bool = false:
	set(v):
		race_finished = v
		if v:
			race_has_finished.emit()

@export var in_countdown: bool = false:
	set(v):
		in_countdown = v
		in_countdown_changed.emit(v)
@export var countdown_state: CountdownState = CountdownState.IDLE:
	set(v):
		countdown_state = v
		countdown_state_changed.emit(v)


enum GameMode {
	UNSET,
	AGAINST_CLOCK,
	VERSUS,
}

enum SpeedMode {
	UNSET,
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

#func _process(_delta):
	#DebugDraw2D.set_text("%d" % multiplayer.get_unique_id(), start_lap_us)
