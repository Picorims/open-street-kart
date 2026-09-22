# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name Global extends Node

enum KartMode {
	UNSET,
	USER,
	BOT,
}

var is_game_running := false

class Math:
	## given a factor between 0 and 1, apply proportional easing.
	static func ease(old: Vector3, new: Vector3, factor: float):
		return old * factor + new * (1.0 - factor)
