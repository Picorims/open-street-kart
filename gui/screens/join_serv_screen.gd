# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name JoinServScreen extends CenterContainer

@onready var join_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/JoinButton
@onready var back_button: AtomGUIBlurredBgndMenuButton = $UIBlockContainer/BackButton

@onready var _address: LineEdit = $UIBlockContainer/Address
@onready var _port: SpinBox = $UIBlockContainer/Port
@onready var _username: LineEdit = $UIBlockContainer/Username
@onready var _password: LineEdit = $UIBlockContainer/Password
@onready var _error: Label = $UIBlockContainer/Error

signal join(address: String, port: String, username: String, password: String)
signal back

func _ready() -> void:
	join_button.pressed.connect(func():
		join.emit(_address.text, int(_port.value), _password.text)
	)
	back_button.pressed.connect(func():
		back.emit()
	)

func set_status_message(msg: String):
	_error.text = msg

func get_username():
	return _username.text
