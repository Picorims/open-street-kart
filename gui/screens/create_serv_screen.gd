# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name CreateServScreen extends CenterContainer

signal create(port: String, username: String, password: String)
signal back

@onready var _create_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/CreateButton
@onready var _back_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/BackButton

@onready var _port: SpinBox = $UIBlockContainer/Port
@onready var _username: LineEdit = $UIBlockContainer/Username
@onready var _password: LineEdit = $UIBlockContainer/Password
@onready var _error: Label = $UIBlockContainer/Error



func _ready() -> void:
	_create_button.pressed.connect(func():
		create.emit(int(_port.value), _password.text)
	)
	_back_button.pressed.connect(func():
		back.emit()
	)
	_username.grab_focus()

func set_status_message(msg: String):
	_error.text = msg

func get_username():
	return _username.text
