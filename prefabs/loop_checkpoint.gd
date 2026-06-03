# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name LoopCheckpoint extends TrackCheckpoint

func _ready() -> void:
	super ()
	self.debug_draw_box_color = Color(1, 0.5, 0)
	self.debug_draw_arrow_color = Color(0.6, 0.3, 0)
	self.debug_shape_fill_color = Color(1, 0.5, 0, 0.4)
