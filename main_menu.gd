extends Control

@onready var look_sensitivity_slider:HSlider = $TabContainer/Settings/VBoxContainer/LookSensitivity

@onready var username_input:LineEdit = $TabContainer/Settings/VBoxContainer/UserName

@onready var join_ip:LineEdit = $"TabContainer/Join Server/VBoxContainer/HBoxContainer/IPAddressInput"
@onready var join_port:LineEdit = $"TabContainer/Join Server/VBoxContainer/HBoxContainer/PortInput"

@onready var host_port:LineEdit = $"TabContainer/Host Server/VBoxContainer/HBoxContainer/PortInput"
@onready var upnp_checkbox:CheckBox = $"TabContainer/Host Server/VBoxContainer/HBoxContainer/UPnPCheckBox"


signal join(ip, port)
signal host(port, upnp)


func get_username():
	return username_input.placeholder_text if username_input.text == "" else username_input.text

func get_host_port():
	return host_port.placeholder_text.to_int() if host_port.text == "" else host_port.text.to_int()

func get_join_port():
	return join_port.placeholder_text.to_int() if join_port.text == "" else join_port.text.to_int()


func _ready():
	look_sensitivity_slider.value = ProjectSettings.get_setting("gameplay/look_sensitivity")


func _on_look_sensitivity_value_changed(value):
	ProjectSettings.set_setting("gameplay/look_sensitivity", value)


func _on_join_button_pressed():
	join.emit(join_ip.text, get_join_port())


func _on_host_button_pressed():
	host.emit(get_host_port(), upnp_checkbox.button_pressed)
