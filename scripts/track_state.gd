# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name TrackState extends Node

@export var loopCheckpoints: Array[LoopCheckpoint] = []
@export var playerSpawner: PlayerSpawner = null

const RACE_HUD_SCENE: PackedScene = preload("res://gui/race_hud.tscn")

var _startUs: float = 0
var _startLapUs: Dictionary[String, float]
var _durationsUs: Dictionary[String, Array] # is Array[float]
var _totalUs: Dictionary[String, float]
var _raceHUD: RaceHUD

enum Mode {
	AGAINST_CLOCK
}

func _ready() -> void:
	assert(loopCheckpoints.size() > 0, "ERROR: No loop checkpoint list specified.")
	assert(playerSpawner != null, "ERROR: No player spawner specified.")
	
	DebugDraw2D.begin_text_group("Durations")
	for i in range(loopCheckpoints.size()):
		DebugDraw2D.set_text("Lap {0}".format([i+1]), "-", 0, Color(1,1,0), 1_000_000_000)
	DebugDraw2D.set_text("Total", "-", 0, Color(1,1,0), 1_000_000_000)
	DebugDraw2D.end_text_group()
	
	init(Mode.AGAINST_CLOCK)

func init(mode: Mode):
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

		)
	
	_raceHUD = RACE_HUD_SCENE.instantiate()
	add_child(_raceHUD)
	
	playerSpawner.countdown()
	playerSpawner.go.connect(func ():
		start()
	)


func start():
	_startUs = Time.get_ticks_usec()

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
	for c in playerSpawner.carRootNodes:
		var entry: _OffsetEntry = _OffsetEntry.new()
		entry.carName = c.name
		entry.carDisplayName = c.displayName
		entry.carOffset = c.get_race_path_offset()
		entry.color = c.material.albedo_color
		var insertPos = 0
		
		if (rankings.size() == 0):
			rankings.append(entry)
			continue
		
		var inserted: bool = false
		while (insertPos < rankings.size()):
			if (rankings[insertPos].carOffset > entry.carOffset):
				rankings.insert(insertPos, entry)
				inserted = true
				break
			insertPos += 1
		if (not inserted):
			rankings.append(entry)
			
	var ratios: Dictionary[String, RaceHUD.RatioEntry] = {}
	var pathLength: float = max(playerSpawner.racePath.curve.get_baked_length(), 0.01)
	var distanceFirstToLast: float = rankings[-1].carOffset - rankings[0].carOffset
	for r in rankings:
		var entry: RaceHUD.RatioEntry = RaceHUD.RatioEntry.new()
		entry.ratio = (r.carOffset - rankings[0].carOffset) / max(distanceFirstToLast, 0.01)
		entry.color = r.color
		ratios[r.carDisplayName] = entry
	_raceHUD.display_ratios(ratios)
	_raceHUD.update_group_pos(rankings[0].carOffset / pathLength, rankings[-1].carOffset / pathLength)
