# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

## Used by TrackStateModel to represent ranking data.
class_name TrackOffsetEntries extends Resource

@export var ids: Array[String] = []
@export var car_display_names: Dictionary[String, String] = {}
@export var car_offsets: Dictionary[String, float] = {}
@export var colors: Dictionary[String, Color] = {}
@export var rankings: Dictionary[String, int] = {}
