# Open Street Kart is an arcade kart game where you race in real life areas reconstructed from Open Street Map
# Copyright (c) 2025-2026 Charly Schmidt aka Picorims<picorims.contact@gmail.com> and Open Street Kart contributors

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.


class_name ButtonSignalEntry

var button: AtomGUIBlurredBgndMenuButton
var signal_ref: Signal

func _init(btn: AtomGUIBlurredBgndMenuButton, sign: Signal) -> void:
	button = btn
	signal_ref = sign

static func link_signals(entries: Array[ButtonSignalEntry]):
	for entry in entries:
		entry.button.pressed.connect(func():
			entry.signal_ref.emit()
		)
