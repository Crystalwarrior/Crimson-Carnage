extends Control


@onready var chat_box:Control = $Chat

signal chat(msg)


func _on_chat_send(msg):
	chat.emit(msg)
