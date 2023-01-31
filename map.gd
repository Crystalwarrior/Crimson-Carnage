extends Node3D


@onready var main_menu:Control = $UI/MainMenu


func _unhandled_input(event):
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo(): toggle_menu(not main_menu.visible)


func capture_mouse(capture : bool) -> void:
	if capture:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func toggle_menu(toggle : bool) -> void:
	capture_mouse(not toggle)
	main_menu.set_visible(toggle)
