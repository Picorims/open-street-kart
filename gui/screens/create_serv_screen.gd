# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name CreateServScreen extends CenterContainer

@onready var create_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/CreateButton
@onready var back_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/BackButton

@onready var port: SpinBox = $UIBlockContainer/Port
@onready var username: LineEdit = $UIBlockContainer/Username
@onready var password: LineEdit = $UIBlockContainer/Password

signal create(port: String, username: String, password: String)
signal back

func _ready() -> void:
	create_button.pressed.connect(func():
		create.emit(int(port.value), username.text, password.text)
	)
	back_button.pressed.connect(func():
		back.emit()
	)
