# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

class_name ConfigureMPGameScreen extends VBoxContainer

signal confirm(speed: TrackStateModel.SpeedMode, total_cars: int)
signal speed_picker_changed(selected: int)
signal cars_count_picker_changed(selected: int)

@export var is_host = false
@onready var buttons_v_box_container: VBoxContainer = $MarginContainer/UIBlockContainer/ButtonsVBoxContainer
@onready var _ok_button: AtomGUIBlurredBgndMenuButton = $MarginContainer/UIBlockContainer/MarginContainer/OKButton
@onready var _speed_picker: AtomGUILinearOptionPicker = $MarginContainer/UIBlockContainer/ButtonsVBoxContainer/SpeedPicker
@onready var _cars_count_picker: AtomGUILinearOptionPicker = $MarginContainer/UIBlockContainer/ButtonsVBoxContainer/CarsCountPicker

func _ready() -> void:
	print("ready. is_host is: ", is_host)
	if is_host:
		print("focused mp config")
		_speed_picker.grab_focus()
		_ok_button.pressed.connect(func():
			var speed: TrackStateModel.SpeedMode = TrackStateModel.SpeedMode.CHILL
			if _speed_picker.selected == 0:
				speed = TrackStateModel.SpeedMode.CHILL
			elif _speed_picker.selected == 1:
				speed = TrackStateModel.SpeedMode.CASUAL
			elif _speed_picker.selected == 2:
				speed = TrackStateModel.SpeedMode.CHALLENGING
			elif _speed_picker.selected == 3:
				speed = TrackStateModel.SpeedMode.CRAZY
			else:
				push_error("Configure multiplayer screen: unknown speed mode for confirmation. i: %d" % [_speed_picker.selected])
				return
			
			var cars_count: int = 0
			if _cars_count_picker.selected == 0:
				cars_count = 4
			elif _cars_count_picker.selected == 0:
				cars_count = 8
			if _cars_count_picker.selected == 0:
				cars_count = 12
			if _cars_count_picker.selected == 0:
				cars_count = 16
			else:
				push_error("Configure multiplayer screen: unknown cars count for confirmation. i: %d" % [_cars_count_picker.selected])
				return
			confirm.emit(speed, cars_count)
		)
		_speed_picker.changed.connect(func(v): speed_picker_changed.emit(v))
		_cars_count_picker.changed.connect(func(v): cars_count_picker_changed.emit(v))
	else:
		print("read-only mp config")
		for child: AtomGUILinearOptionPicker in buttons_v_box_container.get_children():
			child.readonly = true
			child.focus_mode = Control.FOCUS_NONE
		_ok_button.disabled = true
	

func set_speed_selected(selected: int):
	_speed_picker.selected = selected

func set_cars_count_selected(selected: int):
	_cars_count_picker.selected = selected
	
