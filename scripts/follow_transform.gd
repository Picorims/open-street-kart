# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends BackBufferCopy

@export var target: Control

func _process(delta: float) -> void:
	if (target != null):
		self.global_position = target.global_position
		self.transform = target.get_transform()
		self.rect = Rect2(Vector2.ZERO, target.size)
