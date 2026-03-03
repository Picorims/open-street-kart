# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name AirBomb extends Node3D

const EXPLOSION_DURATION_SECONDS: float = 0.2
const EXPLOSION_RADIUS: float = 16  # should match area3D
const EXPLOSION_FORCE = 100000
const MAX_FORCE = EXPLOSION_FORCE

@export var exploding_debug_material: StandardMaterial3D = null

var init_velocity: Vector3 = Vector3.ZERO:
	set(v):
		init_velocity = v
		_apply_velocity = true
		
var _apply_velocity: bool = false
var _ellapsed: float = 0
var _explosion_start: float = -1
var _exploding: bool = false

func _ready() -> void:
	var coll_aura: CollisionShape3D = $RigidBody3D/ExplosionArea3D/CollisionShape3D
	assert(is_instance_of(coll_aura.shape, SphereShape3D))
	var shape: SphereShape3D = coll_aura.shape
	shape.radius = EXPLOSION_RADIUS
	
	var area: Area3D = $RigidBody3D/ExplosionArea3D
	area.monitoring = false
	
	var mesh_aura: MeshInstance3D = $RigidBody3D/AuraMesh
	assert(is_instance_of(mesh_aura.mesh, SphereMesh))
	var mesh: SphereMesh = mesh_aura.mesh
	mesh.height = 2 * EXPLOSION_RADIUS
	mesh.radius = EXPLOSION_RADIUS
	
	mesh_aura.visible = false

func _physics_process(delta: float) -> void:
	_ellapsed += delta
	if _apply_velocity:
		$RigidBody3D.linear_velocity = init_velocity
		_apply_velocity = false
	if _exploding and _explosion_start < 0:
		_explosion_start = _ellapsed

func _process(delta: float) -> void:
	if _exploding and _ellapsed - _explosion_start > EXPLOSION_DURATION_SECONDS:
		self.queue_free()

func _on_rigid_body_3d_body_entered(body: Node) -> void:
	if _exploding:
		push_warning("Tried to explode an air bomb more than once.")
		return
	print("air bomb triggered by: " + body.name)
	_exploding = true
	var area: Area3D = $RigidBody3D/ExplosionArea3D
	area.monitoring = true
	area.monitorable = true
	
	$RigidBody3D/MeshInstance3D.material_override = exploding_debug_material
	$RigidBody3D.freeze = true
	$RigidBody3D/AuraMesh.visible = true

func _on_explosion_area_3d_body_entered(body: Node3D) -> void:
	if not _exploding:
		push_warning("Tried to apply air bomb explosion before being enabled.")
		return
	var rigid_body: RigidBody3D
	if not is_instance_of(body, RigidBody3D):
		return
	else:
		rigid_body = body
	print(body)
	var area: Area3D = $RigidBody3D/ExplosionArea3D
	# grows with time, so we need to invert it so it reduces with time instead.
	var time_intensity: float = ((_ellapsed - _explosion_start) / EXPLOSION_DURATION_SECONDS * -1) + 1
	var distance_intensity: float = body.global_position.distance_to(area.global_position) / EXPLOSION_RADIUS
	var direction: Vector3 = (body.global_position - area.global_position).normalized()
	var force: Vector3 = time_intensity * distance_intensity * direction * EXPLOSION_FORCE / 10
	force += Vector3.UP * 9/10 * EXPLOSION_FORCE
	if force.length() > MAX_FORCE:
		force = force.normalized() * MAX_FORCE
	rigid_body.apply_central_impulse(force)
