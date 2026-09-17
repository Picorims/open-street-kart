# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TrackStateClient extends Node

const RACE_HUD_SCENE: PackedScene = preload("res://gui/race_hud.tscn")
const RACE_FINISHED_GUI: PackedScene = preload("res://gui/race_finished_gui.tscn")
const CountdownState = CountdownStateMachine.CountdownState

var track: Track
var model: TrackStateModel = null
var _race_hud: RaceHUD
var _race_finished_gui: RaceFinishedGUI

var _camera := Camera3D.new()
# TODO separate controllable cars per client
## The car that this client is controlling.
var _player_car: CarCustomPhysics2Client
var _cam_target_pos := Vector3.ZERO
var _cam_current_pos := Vector3.ZERO
var _camera_initialized := false

var player_spawner: PlayerSpawner = null

const CAM_DISTANCE_FROM_PLAYER := 4.0
const CAM_HEIGHT_FROM_PLAYER := 1.5
const CAM_UPDATE_MIN_SPEED := 1.0
const CAM_EASING_RATIO_HOR := 0.95
const CAM_EASING_RATIO_VERT := 0.005
const CAM_MAX_SPEED := 0.5

func _ready() -> void:
	pass
	# debug =======================================
	#DebugDraw2D.begin_text_group("Durations")
	#for i in range(loop_checkpoints.size()):
		#DebugDraw2D.set_text("Lap {0}".format([i + 1]), "-", 0, Color(1, 1, 0), 1_000_000_000)
	#DebugDraw2D.set_text("Total", "-", 0, Color(1, 1, 0), 1_000_000_000)
	#DebugDraw2D.end_text_group()

func init():
	assert(player_spawner != null, "missing player spawner.")
	assert(model != null, "missing track model.")
	assert(track != null, "missing track.")
	print("Client: initializing track...")
	
	_race_hud = RACE_HUD_SCENE.instantiate()
	_race_finished_gui = RACE_FINISHED_GUI.instantiate()
	_race_finished_gui.visible = false
	add_child(_race_hud)
	add_child(_race_finished_gui)
	
	# TODO update GUI and visuals once received updated model

	add_child(_camera)
	
	player_spawner.spawned_kart.connect(func(kart: CarCustomPhysics2Client):
		if kart.display_name == "you": #FIXME multiplayer approach
			_player_car = kart
	)
	player_spawner.track = track
	player_spawner.init(TrackStateModel.GameMode.UNSET, TrackStateModel.SpeedMode.UNSET, 0)
	
	model.in_countdown_changed.connect(func(in_countdown):
		print("in countdown: ", in_countdown)
	)
	model.countdown_state_changed.connect(func(state):
		if state == CountdownState.IDLE:
			DebugDraw2D.set_text("countdown", "idle", 0, Color.WHITE, 3)
		elif state == CountdownState.THREE:
			DebugDraw2D.set_text("countdown", 3, 0, Color.WHITE, 3)
		elif state == CountdownState.TWO:
			DebugDraw2D.set_text("countdown", 2, 0, Color.WHITE, 3)
		elif state == CountdownState.ONE:
			DebugDraw2D.set_text("countdown", 1, 0, Color.WHITE, 3)
		elif state == CountdownState.GO:
			DebugDraw2D.set_text("countdown", "GO", 0, Color.WHITE, 3)
	)
	
	model.race_has_finished.connect(func():
		print("client: race finished.")
		_stop()
	)
	
	track.client_manager.get_rpc().c2s_set_ready()
	print("Track state initialization done.")

func _stop():
	_race_hud.visible = false
	
	for k in model.final_rankings.keys():
		var name_str: String = model.display_names.get(k)
		var time_str: String = model.final_times_or_distance.get(k)
		var rank_str: String = model.final_rankings.get(k)
		_race_finished_gui.append_line(rank_str, name_str, time_str)
	
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
	#TODO
	pass
	#if (not _race_finished and _started):
		#var stats_from_first: Dictionary[String, _CarStatsFromFirst] = _process_live_ranking()
		#_process_item_slots(delta, stats_from_first)

func _physics_process(delta: float) -> void:
	pass
	if not _camera_initialized and _player_car != null and _player_car.current_position:
		_init_camera()
		_camera_initialized = true
	if _camera_initialized:
		_update_camera()

func _process_item_slots(delta: float, stats_from_first: Dictionary[String, _CarStatsFromFirst]):
	#TODO
	pass
	#if stats_from_first.is_empty():
		#push_error("Received empty dictionary for slot processing. This should never happen.")
		#return
	#for id in _car_item_slots:
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
		#
		#if is_you:
			#_race_hud.update_item_slots_hud(slot_state.get_display_state())

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
	#TODO
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
		#if r.car_display_name == "you": #HACK
			#_race_hud.set_self_ranking(i)
		#i -= 1
	#_race_hud.display_ratios(ratios)
	#_race_hud.update_group_pos(rankings[0].car_offset / path_length, rankings[-1].car_offset / path_length)
#
	## return distances to first
	#var stats_from_first: Dictionary[String, _CarStatsFromFirst] = {}
	#for id in _ids:
		#var stats = _CarStatsFromFirst.new()
		#stats.distance = abs(rankings[-1].car_offset - rankings_dict.get(id).car_offset)
		#stats.ranking = rankings_dict.get(id).ranking
		#stats_from_first.set(id, stats)
		#
		#
	#return stats_from_first

func _init_camera():
	var car_pos := _player_car.current_position
	var basis := _player_car.car_basis
	
	var local_pos = Vector3.ZERO
	local_pos -= basis.x.slide(Vector3.UP).normalized() * CAM_DISTANCE_FROM_PLAYER
	var pos_ground = car_pos + local_pos
	local_pos += basis.y * CAM_HEIGHT_FROM_PLAYER
	var pos = car_pos + local_pos
	print("Cam init at: ", pos)
	print("Cam will look at: ", car_pos, "from: ", pos_ground)
	#_camera.look_at_from_position(pos_ground, car_pos)
	#_camera.global_position = pos
	_cam_target_pos = local_pos
	_cam_current_pos = _cam_target_pos
	#DebugDraw3D.draw_arrow(pos_ground, car_pos, Color.RED, 0.05, true, 10)
	_camera.current = true
	DebugDraw2D.set_text("_cam_target_pos_cam", _cam_target_pos, 0, Color.WHITE, 5)
	DebugDraw2D.set_text("current_pos_cam", _cam_current_pos, 0, Color.WHITE, 5)
	_update_camera(true)


func _update_camera(force := false):
	if not model.started and not force:
		return
	var car_velocity := _player_car.current_velocity
	var car_position := _player_car.current_position
	var car_basis := _player_car.car_basis
	var meaningless_vel: bool = car_velocity.is_zero_approx() or (abs(car_velocity.x) < 0.1 and abs(car_velocity.x) < 0.1)
	if car_velocity.length() > CAM_UPDATE_MIN_SPEED and not meaningless_vel:
		var dir := car_velocity.normalized()
		if _player_car.car_basis.x.dot(car_velocity) < 0:
			dir *= -1
		_cam_target_pos = -dir.slide(Vector3.UP).normalized() * CAM_DISTANCE_FROM_PLAYER
		# I'll be honest, Idk why PI, but it looks nice with it.
		# When I coded this, I was so desperate that I just went with trying things
		# that might work. Sorry! (Probably only amplifies vertical cam movement.)
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
