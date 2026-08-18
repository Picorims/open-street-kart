# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

@tool
class_name AtomGUILinearOptionPicker extends Control

signal changed(selected: int)

@onready var label: Label = $GridContainer/Label
@onready var options_container: HBoxContainer = $GridContainer/PanelContainer/HBoxContainerOptions
@onready var visual_cursor_panel: Panel = $GridContainer/PanelContainer/CursorContainer/VisualCursorPanel
@onready var arrow_right: TextureRect = $GridContainer/PanelContainer/CursorContainer/ArrowRight
@onready var arrow_left: TextureRect = $GridContainer/PanelContainer/CursorContainer/ArrowLeft



@export var readonly: bool = false
@export var text: String = "Label":
	set(v):
		text = v
		if label != null:
			label.text = v

@export var options_values: Array[String] = ["Option A", "Option B"]
var _options_labels: Array[Label] = []

@export var selected: int = 0:
	set(v):
		if v < 0 or v >= options_values.size():
			push_warning("AtomGUILinearOptionPicker: received unexpected selected index %d" % [v])
			selected = 0
		elif options_values.size() == 0:
			selected = 0
		else:
			selected = v
		if visual_cursor_panel != null:
			_update_cursor_pos()
		changed.emit(v)

@export_tool_button("Refresh options", "RotateRight") var refresh_action = _refresh

func _init() -> void:
	focus_mode = Control.FOCUS_ALL

## Rebuild all label options in the GUI.
func _refresh():
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()
	_options_labels = []
	for i in range(options_values.size()):
		var value = options_values[i]
		var option_label: Label = Label.new()
		option_label.custom_minimum_size = Vector2(96,0)
		option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_label.text = value
		option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		options_container.add_child(option_label)
		_options_labels.append(option_label)

## Adjust the visual cursor panel to reflect the selected option.
func _update_cursor_pos():
	var step: float = 1.0 / options_values.size()
	visual_cursor_panel.anchor_left = selected * step
	visual_cursor_panel.anchor_right = (selected + 1) * step
	var arrows_visible: bool = not readonly and has_focus()
	arrow_left.visible = arrows_visible
	arrow_right.visible = arrows_visible

func _ready() -> void:
	label.text = text
	_refresh()
	_update_cursor_pos()
	focus_entered.connect(_update_cursor_pos)
	focus_exited.connect(_update_cursor_pos)

func _gui_input(event: InputEvent) -> void:
	if readonly:
		return
	if Input.is_action_just_pressed("ui_left"):
		var new_v := selected - 1
		if new_v < 0:
			selected = options_values.size() - 1
		else:
			selected = new_v
	elif Input.is_action_just_pressed("ui_right"):
		selected = (selected + 1) % options_values.size()
	_update_cursor_pos()
