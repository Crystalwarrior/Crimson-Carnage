extends Node

@onready var main_menu:Control = $"../UI/MainMenu"
@onready var hud:Control = $"../UI/HUD"

@onready var join_ip:LineEdit = $"../UI/MainMenu/TabContainer/Join Server/VBoxContainer/HBoxContainer/IPAddressInput"
@onready var join_port:LineEdit = $"../UI/MainMenu/TabContainer/Join Server/VBoxContainer/HBoxContainer/PortInput"

@onready var host_port:LineEdit = $"../UI/MainMenu/TabContainer/Host Server/VBoxContainer/HBoxContainer/PortInput"

@onready var health_bar:ProgressBar = $"../UI/HUD/HealthBar"
@onready var damage_overlay:Control = $"../UI/HUD/DamageOverlay"

const Player = preload("res://player.tscn")
var enet_peer = ENetMultiplayerPeer.new()

func get_host_port():
	return host_port.placeholder_text.to_int() if host_port.text == "" else host_port.text.to_int()

func get_join_port():
	return join_port.placeholder_text.to_int() if join_port.text == "" else join_port.text.to_int()

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_server(get_host_port())
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	
#	upnp_setup()

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_client(join_ip.text, get_join_port())
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)
	respawn_player(peer_id)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func respawn_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		var spawnpoint = get_spawnpoint()
		if spawnpoint:
			print("Found spawn point, spawning on ", spawnpoint.name)
			player.global_transform = spawnpoint.global_transform
		else:
			print("No valid spawn point found, spawning on ZERO")
			player.position = Vector3.ZERO
		player.hand_animation.stop()
		player.hand_animation.play("idle")
		player.invincible_timer.start()
		player.set_health.rpc(100.0)
		player.invincibility.rpc(3.0)

func get_spawnpoint():
	var spawn_array = $"../SpawnPoints".get_children()
	spawn_array.shuffle()
	for child in spawn_array:
		if child.usable:
			return child
	return null

func update_health_bar(health_value):
	var difference = health_value - health_bar.value
	# Difference is negative, we lost health
	if difference < 0:
		damage_overlay.modulate.r = 1.0
		damage_overlay.modulate.g = 0.0
		damage_overlay.modulate.b = 0.0
		damage_overlay.modulate.a = -(100.0 / difference)
	# We gained health
	else:
		damage_overlay.modulate.r = 0.0
		damage_overlay.modulate.g = 1.0
		damage_overlay.modulate.b = 0.0
		damage_overlay.modulate.a = 100.0 / difference

	if health_value <= 0:
		respawn_player(multiplayer.get_unique_id())
		health_value = 100.0
	health_bar.value = health_value
	health_bar.get_node("Label").text = str(health_value)

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)


func _process(delta):
	# Reduce alpha over time
	damage_overlay.modulate.a = clampf(damage_overlay.modulate.a - delta, 0, 1.0)


#func upnp_setup():
#	var upnp = UPNP.new()
#
#	var discover_result = upnp.discover()
#	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
#		"UPNP Discover Failed! Error %s" % discover_result)
#
#	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
#		"UPNP Invalid Gateway!")
#
#	var map_result = upnp.add_port_mapping(PORT)
#	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
#		"UPNP Port Mapping Failed! Error %s" % map_result)
#
#	print("Success! Join Address: %s" % upnp.query_external_address())
