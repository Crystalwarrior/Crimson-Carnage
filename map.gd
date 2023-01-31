extends Node3D


func _unhandled_input(event):
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo(): capture_mouse(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)


func capture_mouse(capture : bool) -> void:
	if capture:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
