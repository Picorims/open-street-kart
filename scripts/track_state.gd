# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TrackState extends Node

@export var loopCheckpoints: Array[LoopCheckpoint] = []
@export var playerSpawner: PlayerSpawner = null

const RACE_HUD_SCENE: PackedScene = preload("res://gui/race_hud.tscn")
const RACE_FINISHED_GUI: PackedScene = preload("res://gui/race_finished_gui.tscn")

var _started = false
var _startUs: float = 0
var _startLapUs: Dictionary[String, float]
var _durationsUs: Dictionary[String, Array] # is Array[float]
## stored in order of reaching finish line
var _totalUs: Dictionary[String, float]
var _displayNames: Dictionary[String, String]
var _raceHUD: RaceHUD
var _raceFinishedGUI: RaceFinishedGUI

var _lastEstimatedRankings: Array[_OffsetEntry] = []
var _raceFinished: bool = false

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

func _ready() -> void:
	assert(loopCheckpoints.size() > 0, "ERROR: No loop checkpoint list specified.")
	assert(playerSpawner != null, "ERROR: No player spawner specified.")
	
	DebugDraw2D.begin_text_group("Durations")
	for i in range(loopCheckpoints.size()):
		DebugDraw2D.set_text("Lap {0}".format([i+1]), "-", 0, Color(1,1,0), 1_000_000_000)
	DebugDraw2D.set_text("Total", "-", 0, Color(1,1,0), 1_000_000_000)
	DebugDraw2D.end_text_group()

func init(mode: GameMode, speed: SpeedMode):
	print("Initializing track state...")
	for i in range(loopCheckpoints.size()):
		var c: LoopCheckpoint = loopCheckpoints[i]
		c.car_entered.connect(func (car: CarCustomPhysics2):
			var id: String = car.name
			if (!_durationsUs.has(id)):
				_durationsUs.set(id, [])
			# if skipped a lap checkpoint, ignore
			if (_durationsUs.get(id).size() != i): 
				return
			
			# Lap start never initialized since it is the first detection of this car.
			# We initialize it here.
			if (i == 0):
				_startLapUs.set(id, _startUs)
			
			var now = Time.get_ticks_usec()
			var duration: float = now - _startLapUs.get(id)
			_durationsUs.get(id).append(duration)
			_startLapUs.set(id, now)
			
			DebugDraw2D.set_text("Lap {0}".format([i+1]), _pretty_duration_from_us(duration), 0, Color(1,1,0), 1_000_000_000)
			
			if (i == loopCheckpoints.size()-1):
				_totalUs.set(id, now - _startUs)
				DebugDraw2D.set_text("Total", _pretty_duration_from_us(now - _startUs), 0, Color(1,1,0), 1_000_000_000)
				if (car.display_name == "you"):
					_stop()

		)
	
	_raceHUD = RACE_HUD_SCENE.instantiate()
	_raceFinishedGUI = RACE_FINISHED_GUI.instantiate()
	_raceFinishedGUI.visible = false
	add_child(_raceHUD)
	add_child(_raceFinishedGUI)
	
	playerSpawner.init(mode, speed)
	for c in playerSpawner.car_root_nodes:
		_displayNames.set(c.name, c.display_name)

	playerSpawner.countdown()
	playerSpawner.go.connect(func ():
		start()
	)
	print("Track state initialization done.")


func start():
	_startUs = Time.get_ticks_usec()
	_started = true

func _stop():
	_raceFinished = true
	_raceHUD.visible = false
	var registered: Array[String] = []
	var currentRank = 1
	# done
	for k in _totalUs.keys():
		registered.append(k)
		var nameStr: String = _displayNames.get(k)
		var positionStr: String = "{0}".format([currentRank])
		var timeStr: String = _pretty_duration_from_us(_totalUs.get(k))
		_raceFinishedGUI.append_line(positionStr, nameStr, timeStr)
		
		currentRank += 1
	
	# was still running
	# From last to first, because the array is sorted in ascending order
	# by offset from the start of the track. So the lowest offset, in other
	# words the start of the array, is last, and thus shall be inserted as
	# last as well. Hence the need to iterate in reverse order.
	for i in range(_lastEstimatedRankings.size()-1, -1, -1):
		var rankingInfo: _OffsetEntry = _lastEstimatedRankings[i]
		if registered.has(rankingInfo.carName):
			# done, skip
			continue
		
		var nameStr: String = _displayNames.get(rankingInfo.carName)
		var positionStr: String = "{0}".format([currentRank])
		var timeStr: String = "{0}m".format(["%.2f" % rankingInfo.carOffset])
		_raceFinishedGUI.append_line(positionStr, nameStr, timeStr)
		
		currentRank += 1
	_raceFinishedGUI.visible = true

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
	if (!_raceFinished && _started):
		_process_live_ranking()

class _OffsetEntry:
	var carName: String
	var carDisplayName: String
	var carOffset: float
	var color: Color

## Updates ranking info on the HUD during the track race.
## Not responsible for the final ranking.
func _process_live_ranking() -> void:
	## smaller to bigger
	var rankings: Array[_OffsetEntry] = []
	if (playerSpawner.car_root_nodes.size() == 0):
		# spawner not ready
		return
		
	for c in playerSpawner.car_root_nodes:
		var entry: _OffsetEntry = _OffsetEntry.new()
		entry.carName = c.name
		entry.carDisplayName = c.display_name
		entry.carOffset = c.get_race_path_offset()
		entry.color = c.material.albedo_color
		rankings.append(entry)
	
	# sort ascending
	rankings.sort_custom(func(a: _OffsetEntry, b: _OffsetEntry) -> bool:
		return a.carOffset < b.carOffset
	)
	assert(rankings.size() > 0, "rankings empty")
	
	_lastEstimatedRankings = rankings
	
	var ratios: Dictionary[String, RaceHUD.RatioEntry] = {}
	var pathLength: float = max(playerSpawner.race_path.curve.get_baked_length(), 0.01)
	var distanceFirstToLast: float = rankings[-1].carOffset - rankings[0].carOffset
	var i: int = rankings.size() # because we want to start ranking value at 1
	for r in rankings:
		var entry: RaceHUD.RatioEntry = RaceHUD.RatioEntry.new()
		entry.ratio = (r.carOffset - rankings[0].carOffset) / max(distanceFirstToLast, 0.01)
		entry.color = r.color
		ratios[r.carDisplayName] = entry
		if r.carDisplayName == "you":
			_raceHUD.set_self_ranking(i)
		i -= 1
	_raceHUD.display_ratios(ratios)
	_raceHUD.update_group_pos(rankings[0].carOffset / pathLength, rankings[-1].carOffset / pathLength)
