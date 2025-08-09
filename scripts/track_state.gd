class_name TrackState extends Node

@export var loopCheckpoints: Array[LoopCheckpoint] = []
@export var playerSpawner: PlayerSpawner = null

var _startUs: float = 0
var _startLapUs: Dictionary[String, float]
var _durationsUs: Dictionary[String, Array] # is Array[float]
var _totalUs: Dictionary[String, float]

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
