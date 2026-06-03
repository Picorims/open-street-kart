# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name PickTrackScreen extends Control

signal track_selected(mode: Main.Track)

const TRACKS_DICTIONARY: Dictionary[String, Main.Track] = {
	"Orsay Hills": Main.Track.ORSAY_HILLS,
}

func _ready() -> void:
	var list: ItemList = $MarginContainer/UIBlockContainer/TracksList/ItemList
	assert(list != null, "track list is undefined.")
	assert(TRACKS_DICTIONARY.keys().size() > 0, "no track in list.")
	for track in TRACKS_DICTIONARY.keys():
		list.add_item(track)
	list.select(0)
	
	var validate_button: AtomGUIBlurredBgndMenuButton = $MarginContainer/UIBlockContainer/AtomGUIBlurredBgndMenuButton_Go
	assert(validate_button != null, "validate button for track list is undefined.")
	validate_button.pressed.connect(func():
		var items: PackedInt32Array = list.get_selected_items()
		if (items.size() != 1):
			push_error("unexpected item count (not 1) for track list selected item(s)")
			return
	
		var key_from_index: String = TRACKS_DICTIONARY.keys().get(items[0])
		track_selected.emit(TRACKS_DICTIONARY.get(key_from_index))
	)
