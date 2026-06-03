# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name TrackOrsay extends Track

func apply_osm_mutations_action(root: Node3D, generator: OSMDataGenerator):
	# Y += 0.5
	generator.get_collidable_asset(root, "Bin__node_7651663290").global_position = Vector3(
		-2189.7,
		-45.36 + 0.5,
		2721.17,
	)
	
	# rotate 180°
	generator.get_collidable_asset(root, "Bench__node_7636020085").global_rotation_degrees = Vector3(
		-3.7,
		0.4 + 180,
		-6.3,
	)
