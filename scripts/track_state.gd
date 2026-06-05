# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TrackState extends Node

@export var loop_checkpoints: Array[LoopCheckpoint] = []
@export var player_spawner: PlayerSpawner = null

const RACE_HUD_SCENE: PackedScene = preload("res://gui/race_hud.tscn")
const RACE_FINISHED_GUI: PackedScene = preload("res://gui/race_finished_gui.tscn")

var _mode: GameMode
var _speed: SpeedMode
var _started = false
var _start_us: float = 0
## IDs and car names are equivalent
var _ids: Array[String] = []
var _start_lap_us: Dictionary[String, float]
var _durations_us: Dictionary[String, Array] # is Array[float]
## stored in order of reaching finish line
var _total_us: Dictionary[String, float]
var _display_names: Dictionary[String, String]
var _car_item_slots: Dictionary[String, PlayerItemSlotsState]
var _race_hud: RaceHUD
var _race_finished_gui: RaceFinishedGUI

var _camera := Camera3D.new()
var _player_car: CarCustomPhysics2
var _cam_target_pos := Vector3.ZERO
var _cam_current_pos := Vector3.ZERO

var _last_estimated_rankings: Array[_OffsetEntry] = []
var _race_finished: bool = false
var _track_region_manager: TrackRegionManager = TrackRegionManager.new()
func get_track_region_manager() -> TrackRegionManager:
	return _track_region_manager

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

const TrackSpeedDict: Dictionary[TrackState.SpeedMode, float] = {
	TrackState.SpeedMode.CHILL: 25,
	TrackState.SpeedMode.CASUAL: 30,
	TrackState.SpeedMode.CHALLENGING: 35,
	TrackState.SpeedMode.CRAZY: 40,
}
const OutOfBoundsSpeedDict: Dictionary[TrackState.SpeedMode, float] = {
	TrackState.SpeedMode.CHILL: 6,
	TrackState.SpeedMode.CASUAL: 8,
	TrackState.SpeedMode.CHALLENGING: 9,
	TrackState.SpeedMode.CRAZY: 11,
}

const CAM_DISTANCE_FROM_PLAYER := 4.0
const CAM_HEIGHT_FROM_PLAYER := 1.5
const CAM_UPDATE_MIN_SPEED := 1.0
const CAM_EASING_RATIO_HOR := 0.98
const CAM_EASING_RATIO_VERT := 0.05
const CAM_MAX_SPEED := 0.5

func _ready() -> void:
	assert(loop_checkpoints.size() > 0, "ERROR: No loop checkpoint list specified.")
	assert(player_spawner != null, "ERROR: No player spawner specified.")
	assert(%ProceduralDataHolder != null, "missing procedural data holder")
	
	var _buildings = get_tree().get_nodes_in_group("buildings")
	for n in _buildings:
		get_track_region_manager().register_node(n)
	
	# debug =======================================
	DebugDraw2D.begin_text_group("Durations")
	for i in range(loop_checkpoints.size()):
		DebugDraw2D.set_text("Lap {0}".format([i + 1]), "-", 0, Color(1, 1, 0), 1_000_000_000)
	DebugDraw2D.set_text("Total", "-", 0, Color(1, 1, 0), 1_000_000_000)
	DebugDraw2D.end_text_group()

func init(mode: GameMode, speed: SpeedMode):
	_mode = mode
	_speed = speed
	print("Initializing track state...")
	for i in range(loop_checkpoints.size()):
		var c: LoopCheckpoint = loop_checkpoints[i]
		c.car_entered.connect(func(car: CarCustomPhysics2):
			var id: String = car.name

			if (not _durations_us.has(id)):
				_durations_us.set(id, [])
			# if skipped a lap checkpoint, ignore
			if (_durations_us.get(id).size() != i):
				return
			
			# Lap start never initialized since it is the first detection of this car.
			# We initialize it here.
			if (i == 0):
				_start_lap_us.set(id, _start_us)
			
			var now = Time.get_ticks_usec()
			var duration: float = now - _start_lap_us.get(id)
			_durations_us.get(id).append(duration)
			_start_lap_us.set(id, now)
			
			DebugDraw2D.set_text("Lap {0}".format([i + 1]), _pretty_duration_from_us(duration), 0, Color(1, 1, 0), 1_000_000_000)
			
			if (i == loop_checkpoints.size() - 1):
				_total_us.set(id, now - _start_us)
				DebugDraw2D.set_text("Total", _pretty_duration_from_us(now - _start_us), 0, Color(1, 1, 0), 1_000_000_000)
				if (car.display_name == "you"):
					_stop()

		)
	
	_race_hud = RACE_HUD_SCENE.instantiate()
	_race_finished_gui = RACE_FINISHED_GUI.instantiate()
	_race_finished_gui.visible = false
	add_child(_race_hud)
	add_child(_race_finished_gui)
	
	player_spawner.init(mode, speed)
	for c in player_spawner.car_root_nodes:
		_display_names.set(c.name, c.display_name)
		_ids.append(c.name)
		if c.display_name == "you":
			_player_car = c

	add_child(_camera)
	_init_camera()

	player_spawner.countdown()
	player_spawner.go.connect(func():
		start()
	)
	print("Track state initialization done.")


func start():
	_start_us = Time.get_ticks_usec()
	_started = true

	for id in _ids:
		_car_item_slots[id] = PlayerItemSlotsState.new(TrackSpeedDict.get(_speed), _mode)

func _stop():
	_race_finished = true
	_race_hud.visible = false
	var registered: Array[String] = []
	var current_rank = 1
	# done
	for k in _total_us.keys():
		registered.append(k)
		var name_str: String = _display_names.get(k)
		var position_str: String = "{0}".format([current_rank])
		var time_str: String = _pretty_duration_from_us(_total_us.get(k))
		_race_finished_gui.append_line(position_str, name_str, time_str)
		
		current_rank += 1
	
	# was still running
	# From last to first, because the array is sorted in ascending order
	# by offset from the start of the track. So the lowest offset, in other
	# words the start of the array, is last, and thus shall be inserted as
	# last as well. Hence the need to iterate in reverse order.
	for i in range(_last_estimated_rankings.size() - 1, -1, -1):
		var ranking_info: _OffsetEntry = _last_estimated_rankings[i]
		if registered.has(ranking_info.id):
			# done, skip
			continue
		
		var name_str: String = _display_names.get(ranking_info.id)
		var position_str: String = "{0}".format([current_rank])
		var time_str: String = "{0}m".format(["%.2f" % ranking_info.car_offset])
		_race_finished_gui.append_line(position_str, name_str, time_str)
		
		current_rank += 1
	_race_finished_gui.visible = true

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
	if (not _race_finished and _started):
		var stats_from_first: Dictionary[String, _CarStatsFromFirst] = _process_live_ranking()
		_process_item_slots(delta, stats_from_first)
	_update_camera()

func _physics_process(delta: float) -> void:
	get_track_region_manager().tick(delta)

func _process_item_slots(delta: float, stats_from_first: Dictionary[String, _CarStatsFromFirst]):
	if stats_from_first.is_empty():
		push_error("Received empty dictionary for slot processing. This should never happen.")
		return
	for id in _car_item_slots:
		var is_you: bool = _display_names.get(id) == "you"
		var slot_state: PlayerItemSlotsState = _car_item_slots.get(id)
		var stats: _CarStatsFromFirst = stats_from_first.get(id)
		var item_used: PlayerItemSlotsState.SlotItem = slot_state.tick(
			delta,
			stats.distance,
			Input.is_action_just_pressed("use") and is_you,
			stats.ranking
		)
		if not item_used == PlayerItemSlotsState.SlotItem.EMPTY:
			player_spawner.get_car_by_id(id).use_item(item_used)
		
		if is_you:
			_race_hud.update_item_slots_hud(slot_state.get_display_state())

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
	## smaller to bigger
	var rankings: Array[_OffsetEntry] = []
	var rankings_dict: Dictionary[String, _OffsetEntry] = {}
	if (player_spawner.car_root_nodes.size() == 0):
		# spawner not ready
		return {}
		
	for c in player_spawner.car_root_nodes:
		var entry: _OffsetEntry = _OffsetEntry.new()
		entry.id = c.name
		entry.car_display_name = c.display_name
		entry.car_offset = c.get_race_path_offset()
		entry.color = c.material.albedo_color
		rankings.append(entry)
		rankings_dict.set(entry.id, entry)
	
	# sort ascending
	rankings.sort_custom(func(a: _OffsetEntry, b: _OffsetEntry) -> bool:
		return a.car_offset < b.car_offset
	)
	assert(rankings.size() > 0, "rankings empty")
	
	_last_estimated_rankings = rankings.duplicate(true)
	
	var ratios: Dictionary[String, RaceHUD.RatioEntry] = {}
	var path_length: float = max(player_spawner.race_path.curve.get_baked_length(), 0.01)
	var distance_first_to_last: float = rankings[-1].car_offset - rankings[0].car_offset
	var i: int = rankings.size() # because we want to start ranking value at 1
	for r in rankings:
		var entry: RaceHUD.RatioEntry = RaceHUD.RatioEntry.new()
		entry.ratio = (r.car_offset - rankings[0].car_offset) / max(distance_first_to_last, 0.01)
		entry.color = r.color
		ratios[r.car_display_name] = entry
		r.ranking = i
		if r.car_display_name == "you": #HACK
			_race_hud.set_self_ranking(i)
		i -= 1
	_race_hud.display_ratios(ratios)
	_race_hud.update_group_pos(rankings[0].car_offset / path_length, rankings[-1].car_offset / path_length)

	# return distances to first
	var stats_from_first: Dictionary[String, _CarStatsFromFirst] = {}
	for id in _ids:
		var stats = _CarStatsFromFirst.new()
		stats.distance = abs(rankings[-1].car_offset - rankings_dict.get(id).car_offset)
		stats.ranking = rankings_dict.get(id).ranking
		stats_from_first.set(id, stats)
		
		
	return stats_from_first

func _init_camera():
	var pos := _player_car.current_position
	var basis := _player_car.car_basis
	pos -= basis.x * CAM_DISTANCE_FROM_PLAYER
	var pos_ground = pos
	pos += basis.y * CAM_HEIGHT_FROM_PLAYER
	_camera.look_at_from_position(pos_ground, pos)
	_cam_target_pos = pos
	_cam_current_pos = _cam_target_pos

func _update_camera():
	var car_velocity := _player_car.current_velocity
	var car_position := _player_car.current_position
	var car_basis := _player_car.car_basis
	if car_velocity.length() > CAM_UPDATE_MIN_SPEED:
		var dir := car_velocity.normalized()
		if _player_car.car_basis.x.dot(car_velocity) < 0:
			dir *= -1
		_cam_target_pos = -dir.slide(Vector3.UP).normalized() * CAM_DISTANCE_FROM_PLAYER
		# I'll be honest, Idk why PI, but it looks nice with it.
		# When I coded this, I was so desperate that I just went with trying things
		# that might work. Sorry!
		_cam_target_pos.y -= dir.y * PI
	var ratio_h := CAM_EASING_RATIO_HOR
	var ratio_v := CAM_EASING_RATIO_VERT
	_cam_current_pos = Vector3(
		ratio_h * _cam_target_pos.x + (1.0 - ratio_h) * _cam_current_pos.x,
		ratio_v * _cam_target_pos.y + (1.0 - ratio_v) * _cam_current_pos.y,
		ratio_h * _cam_target_pos.z + (1.0 - ratio_h) * _cam_current_pos.z,
	)
	DebugDraw2D.set_text("_cam_target_pos_cam", _cam_target_pos)
	DebugDraw2D.set_text("current_pos_cam", _cam_current_pos)

	var pos = car_position + _cam_current_pos
	_camera.look_at_from_position(pos, car_position)
	pos.y += CAM_HEIGHT_FROM_PLAYER
	_camera.global_position = pos
