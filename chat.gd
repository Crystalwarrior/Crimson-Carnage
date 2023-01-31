extends Control


@onready var chat_input:LineEdit = $ChatInput
@onready var chat_logs:RichTextLabel = $ChatLogs/RichTextLabel
@onready var chat_audio:AudioStreamPlayer = $ChatAudio


signal send(msg)


func _unhandled_input(event):
	if event.is_action("chat") and event.is_pressed() and not event.is_echo():
		if chat_input.has_focus():
			if chat_input.text != "":
				send.emit(chat_input.text)
				chat_input.clear()
			chat_unfocus()
		else:
			chat_focus()
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo():
		chat_unfocus()


func chat_unfocus():
	chat_input.release_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 


func chat_focus():
	chat_input.grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func message_received(msg, noise = true):
	chat_logs.append_text("\n"+msg)
	if noise:
		chat_audio.play()
