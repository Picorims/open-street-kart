# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TrackStateServer extends Node

var loop_checkpoints: Array[LoopCheckpoint] = []
var player_spawner: PlayerSpawner = null
var procedural_data_holder: Node3D
var track: Track = null
var model: TrackStateModel = null
var _countdown_sm: CountdownStateMachine = CountdownStateMachine.new()

var _track_region_manager: TrackRegionManager = TrackRegionManager.new()
func get_track_region_manager() -> TrackRegionManager:
	return _track_region_manager
	
func init(mode: TrackStateModel.GameMode, speed: TrackStateModel.SpeedMode, cars_count: int):
	assert(loop_checkpoints.size() > 0, "ERROR: No loop checkpoint list specified.")
	assert(player_spawner != null, "ERROR: No player spawner specified.")
	assert(procedural_data_holder != null, "missing procedural data holder")
	assert(track != null, "missing track.")
	assert(model != null, "missing track model.")
	
	_countdown_sm.model = model

	model.mode = mode
	model.speed = speed
	print("Initializing track state...")
	for i in range(loop_checkpoints.size()):
		var c: LoopCheckpoint = loop_checkpoints[i]
		c.car_entered.connect(func(car: CarCustomPhysics2):
			var id: String = car.name

			if (not model.durations_us.has(id)):
				model.durations_us.set(id, [])
			# if skipped a lap checkpoint, ignore
			if (model.durations_us.get(id).size() != i):
				return
			
			# Lap start never initialized since it is the first detection of this car.
			# We initialize it here.
			if (i == 0):
				model.start_lap_us.set(id, model.start_us)
			
			var now = Time.get_ticks_usec()
			var duration: float = now - model.start_lap_us.get(id)
			model.durations_us.get(id).append(duration)
			model.start_lap_us.set(id, now)
			
			
			if (i == loop_checkpoints.size() - 1):
				model.total_us.set(id, now - model.start_us)
				if (car.display_name == "you"):
					_stop()

		)
	
	player_spawner.init(mode, speed, cars_count)
	for c in player_spawner.car_root_nodes:
		model.display_names.set(c.name, c.display_name)
		model.ids.append(c.name)

	_countdown_sm.go.connect(func():
		player_spawner.unfreeze_cars()
		model.in_countdown = false
		_start()
	)
	_countdown_sm.countdown()
	print("Track state initialization done.")

## Called AFTER the countdown when the races start ("go").
func _start():
	model.start_us = Time.get_ticks_usec()
	model.started = true

	for id in model.ids:
		model.car_item_slots[id] = PlayerItemSlotsState.new(TrackStateModel.TrackSpeedDict.get(model.speed), model.mode)

## Ends the race, wheither or not all cars crossed the final line 
func _stop():
	model.race_finished = true
	var registered: Array[String] = []
	var current_rank = 1
	# done
	for k in model.total_us.keys():
		registered.append(k)
		var name_str: String = model.display_names.get(k)
		var time_str: String = _pretty_duration_from_us(model.total_us.get(k))
		model.final_rankings.car_display_names.set(k, name_str)
		model.final_rankings.times.set(k, time_str)
		model.final_rankings.rankings.set(k, current_rank)
		
		current_rank += 1
	
	#TODO refactor checkpoint
	
	# was still running
	# From last to first, because the array is sorted in ascending order
	# by offset from the start of the track. So the lowest offset, in other
	# words the start of the array, is last, and thus shall be inserted as
	# last as well. Hence the need to iterate in reverse order.
	for i in range(model.last_estimated_rankings.ids.size() - 1, -1, -1):
		var ids := model.last_estimated_rankings.ids
		var offsets := model.last_estimated_rankings.car_offsets
		var id = ids[i]
		var offset: float = offsets.get(id)
		if registered.has(ids[i]):
			# done, skip
			continue
		
		var name_str: String = model.display_names.get(id)
		var position_str: String = "{0}".format([current_rank])
		var time_str: String = "{0}m".format(["%.2f" % offset])
		model.final_rankings.car_display_names.set(id, name_str)
		model.final_rankings.times.set(id, time_str)
		model.final_rankings.rankings.set(id, current_rank)
		
		current_rank += 1

const US_TO_MINUTES_RATIO = 1_000_000 * 60
const US_TO_SECONDS_RATIO = 1_000_000
const US_TO_MS_RATIO = 1_000

func _pretty_duration_from_us(us: float) -> String:
	var minutes: int = floor(us / US_TO_MINUTES_RATIO)
	var seconds: int = int(floor(us / US_TO_SECONDS_RATIO)) % 60
	var milliseconds: int = int(floor(us / US_TO_MS_RATIO)) % 1_000
	var microseconds: int = int(floor(us)) % 1_000_000
	
	return "{0}:{1}.{2} ({3} us)".format([minutes, seconds, milliseconds, microseconds])

func _process(delta: float) -> void:
	# TODO multi refactor
	pass
	#if (not model.race_finished and model.started):
		#var stats_from_first: Dictionary[String, _CarStatsFromFirst] = _process_live_ranking()
		#_process_item_slots(delta, stats_from_first)

func _physics_process(delta: float) -> void:
	get_track_region_manager().tick(delta)

func _process_item_slots(delta: float, stats_from_first: Dictionary[String, _CarStatsFromFirst]):
	if stats_from_first.is_empty():
		push_error("Received empty dictionary for slot processing. This should never happen.")
		return
	# TODO checkpoint refactor + update/sync model state
	#for id in model.car_item_slots:
		#var is_you: bool = _display_names.get(id) == "you"
		#var slot_state: PlayerItemSlotsState = _car_item_slots.get(id)
		#var stats: _CarStatsFromFirst = stats_from_first.get(id)
		#var item_used: PlayerItemSlotsState.SlotItem = slot_state.tick(
			#delta,
			#stats.distance,
			#Input.is_action_just_pressed("use") and is_you,
			#stats.ranking
		#)
		#if not item_used == PlayerItemSlotsState.SlotItem.EMPTY:
			#player_spawner.get_car_by_id(id).use_item(item_used)

class _OffsetEntry:
	var id: String
	var car_display_name: String
	var car_offset: float
	var color: Color
	var ranking: int
	
class _CarStatsFromFirst:
	var distance: float
	var ranking: int

## Updates ranking info on the HUD during the track race.
## Not responsible for the final ranking.
## Returns the distance to the first car for each id
func _process_live_ranking() -> Dictionary[String, _CarStatsFromFirst]:
	# TODO refactor multi
	pass
	return {}
	
	### smaller to bigger
	#var rankings: Array[_OffsetEntry] = []
	#var rankings_dict: Dictionary[String, _OffsetEntry] = {}
	#if (player_spawner.car_root_nodes.size() == 0):
		## spawner not ready
		#return {}
		#
	#for c in player_spawner.car_root_nodes:
		#var entry: _OffsetEntry = _OffsetEntry.new()
		#entry.id = c.name
		#entry.car_display_name = c.display_name
		#entry.car_offset = c.get_race_path_offset()
		#entry.color = c.material.albedo_color
		#rankings.append(entry)
		#rankings_dict.set(entry.id, entry)
	#
	## sort ascending
	#rankings.sort_custom(func(a: _OffsetEntry, b: _OffsetEntry) -> bool:
		#return a.car_offset < b.car_offset
	#)
	#assert(rankings.size() > 0, "rankings empty")
	#
	#_last_estimated_rankings = rankings.duplicate(true)
	#
	#var ratios: Dictionary[String, RaceHUD.RatioEntry] = {}
	#var path_length: float = max(player_spawner.race_path.curve.get_baked_length(), 0.01)
	#var distance_first_to_last: float = rankings[-1].car_offset - rankings[0].car_offset
	#var i: int = rankings.size() # because we want to start ranking value at 1
	#for r in rankings:
		#var entry: RaceHUD.RatioEntry = RaceHUD.RatioEntry.new()
		#entry.ratio = (r.car_offset - rankings[0].car_offset) / max(distance_first_to_last, 0.01)
		#entry.color = r.color
		#ratios[r.car_display_name] = entry
		#r.ranking = i
		#i -= 1
#
	## return distances to first
	#var stats_from_first: Dictionary[String, _CarStatsFromFirst] = {}
	#for id in model.ids:
		#var stats = _CarStatsFromFirst.new()
		#stats.distance = abs(rankings[-1].car_offset - rankings_dict.get(id).car_offset)
		#stats.ranking = rankings_dict.get(id).ranking
		#stats_from_first.set(id, stats)
		#
		#
	#return stats_from_first
