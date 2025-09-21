# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Manages the item slots and their refill for a player.
##
## spec:
## - Starts with slot 1 empty and other disabled.
## - At initialization, refill time for the slot
## is the min refill time.
## - A slot being after an empty slot in the queue is disabled.
## - If the previous slot is filled, the slot is set as empty
## instead of disabled, with its waiting time determined by the
## distance with the first player. It never changes during the
## wait time processing (so the distance changing has no impact
## until the next time that the slot is in the empty state).
## - A slot with an item reaching expiration or being used
## is replaced by the next item in the queue,
## or an empty (non disabled) slot otherwise.
## - The flow is as follows:
##     - DISABLED -> EMPTY -> <item_type> -> removed from queue, new one at the end.
class_name PlayerItemSlotsState extends Node

## starts at this instance's initialization.
## Then it is increased with _process()'s delta.
var now: float = 0

enum SlotItem {
	DISABLED,
	EMPTY,
	SPEED_BOOST,
}

## initialized as DISABLED with timestamp at parent's now.
class Slot:
	var _type: SlotItem
	var _updated_on_timestamp_s: float = 0
	var lifetime_s: float = 0
	var _parent: PlayerItemSlotsState
	
	func get_type() -> SlotItem:
		return _type
	func set_type(type: SlotItem) -> void:
		_type = type
		_updated_on_timestamp_s = _parent.now
		
	func _init(parent: PlayerItemSlotsState) -> void:
		_parent = parent
		set_type(SlotItem.DISABLED)
	
	## returns true if the time ellapsed is greater
	## than the slot's lifespan.
	func time_is_up() -> bool:
		return _parent.now - _updated_on_timestamp_s > lifetime_s
	
	func is_disabled_or_empty():
		return _type == SlotItem.DISABLED or _type == SlotItem.EMPTY
		
	## ratio between 0 and 1 based on time ellapsed relative
	## to lifespan.
	func get_progress_ratio() -> float:
		if _type == SlotItem.DISABLED:
			return 0
		# no clampf(), it does not behave as expected (misunderstanding)?.
		var ratio: float = (_parent.now - _updated_on_timestamp_s) / max(0.1, lifetime_s)
		return ratio

var _slots: Array[Slot]
var _max_speed: float = 1
const SLOTS_COUNT: int = 3
const ITEM_LIFETIME_SECONDS: float = 30
const MIN_REFILL_TIME_SECONDS: float = 8
const MAX_REFILL_TIME_SECONDS: float = 15
const DISTANCE_FOR_MIN_REFILL: float = 200

func _init(max_speed: float) -> void:
	assert(max_speed > 0, "max speed must be above 0 for slot item picking")
	_max_speed = max_speed
	assert(MAX_REFILL_TIME_SECONDS > MIN_REFILL_TIME_SECONDS, "incorrect min/max constants for item slots.")
	_slots = []
	for i in range(SLOTS_COUNT):
		_slots.append(Slot.new(self))
		if (i == 0):
			_slots[i].set_type(SlotItem.EMPTY)
			_slots[i].lifetime_s = MIN_REFILL_TIME_SECONDS

## pops the first slot, append a new slot at the end
## and returns the type of the first slot.
func _consume_first_slot() -> SlotItem:
	var type: SlotItem = _slots[0].get_type()
	_slots.pop_front()
	_slots.append(Slot.new(self))
	return type

## Tick the process with the provided delta.
## Can be called within a _process().
func tick(delta: float, distance_to_first: float, use_item: bool) -> SlotItem:
	now += delta
	
	if use_item and not _slots[0].is_disabled_or_empty():
		return _consume_first_slot()
	
	# have consistent behavior regardless of the speed.
	# A similar distance is much more significant at a slower speed.
	# It is much more negligible at a higher speed.
	var speed_normalized_distance: float = distance_to_first / _max_speed
	var i: int = 0
	while i < SLOTS_COUNT:
		# TODO fix boucle
		# ensure the next empty slot is in the waiting process
		if i > 0:
			if not _slots[i-1].is_disabled_or_empty() and _slots[i].get_type() == SlotItem.DISABLED:
				_slots[i].set_type(SlotItem.EMPTY)
				# between 0 and 1 for mapping from MIN to MAX.
				var ratio: float = smoothstep(0, DISTANCE_FOR_MIN_REFILL, speed_normalized_distance)
				# close to first = close to MAX
				# far from first = close to MIN (have more items to catch up)
				var min_v: float = MIN_REFILL_TIME_SECONDS
				var max_v: float = MAX_REFILL_TIME_SECONDS
				_slots[i].lifetime_s = min_v + (1.0 - ratio) * (max_v - min_v)
				print("gotta be ", _slots[i].lifetime_s, " cause ratio is ", ratio, " and distance is ", speed_normalized_distance) #FIXME why always max?
		
		# replace empty with item if time ellapsed.
		if (_slots[i].get_type() == SlotItem.EMPTY and _slots[i].time_is_up()):
			_slots[i].set_type(_pick_random_item(speed_normalized_distance))
			_slots[i].lifetime_s = ITEM_LIFETIME_SECONDS
		
		# remove expired item
		if not _slots[i].is_disabled_or_empty() and _slots[i].time_is_up():
			_consume_first_slot()
			i -= 1 # disable the +1 of the loop to not skip the next slot
		
		i += 1
	
	return SlotItem.EMPTY


func _pick_random_item(speed_norm_distance_to_first: float) -> SlotItem:
	# TODO
	push_warning("Random item pick not implemented.")
	return SlotItem.SPEED_BOOST

class SlotDisplayState:
	var progress_ratio: float = 0
	var item: SlotItem = SlotItem.DISABLED
	
func get_display_state() -> Array[SlotDisplayState]:
	var array: Array[SlotDisplayState] = []
	for i in range(SLOTS_COUNT):
		array.append(SlotDisplayState.new())
		array[i].item = _slots[i].get_type()
		array[i].progress_ratio = _slots[i].get_progress_ratio()
	return array
