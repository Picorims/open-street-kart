# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name LocalRaceBoundary extends Area3D

func _ready() -> void:
	self.monitoring = true
	self.body_entered.connect(func (body: Node3D):
		var car: Node3D = body.get_parent_node_3d()
		if (car != null && is_instance_of(car, CarCustomPhysics2)):
			car.respawn()
	)
