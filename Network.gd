extends Node


@onready var main_menu:Control = $"../UI/MainMenu"
@onready var hud:Control = $"../UI/HUD"

@onready var health_bar:ProgressBar = $"../UI/HUD/HealthBar"
@onready var damage_overlay:Control = $"../UI/HUD/DamageOverlay"


const Player = preload("res://player.tscn")
var enet_peer = ENetMultiplayerPeer.new()


func host(port, upnp):
	main_menu.hide()
	hud.show()
	
	enet_peer.create_server(port)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	if upnp:
		upnp_setup(port)


func join(ip, port):
	main_menu.hide()
	hud.show()
	enet_peer.create_client(ip, port)
	multiplayer.multiplayer_peer = enet_peer


func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)
		player.nametag.text = main_menu.get_username()
	respawn_player(peer_id)


func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)
		node.nametag.text = main_menu.get_username()


func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func respawn_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if not player:
		return

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
	player.set_visible(true)
	player.unfreeze()


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

	# this is the dumbest place to handle it (isn't this function ui?)
	if health_value <= 0:
		kill_player.rpc(multiplayer.get_unique_id())

	health_bar.value = health_value
	health_bar.get_node("Label").text = str(health_value)


func _process(delta):
	# Reduce alpha over time
	damage_overlay.modulate.a = clampf(damage_overlay.modulate.a - delta, 0, 1.0)


func upnp_setup(port):
	var upnp = UPNP.new()

	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(port)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)

	print("Success! Join Address: %s" % upnp.query_external_address())


func _on_main_menu_join(ip, port):
	join(ip, port)


func _on_main_menu_host(port, upnp):
	host(port, upnp)


func _on_hud_chat(msg):
	send_chat.rpc(main_menu.get_username() + ": " + msg)


@rpc("any_peer", "call_local")
func send_chat(msg, noise = true):
	hud.chat_box.message_received(msg, noise)


@rpc("any_peer", "call_local")
func kill_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if not player:
		return

	print(player.last_hit)
	if player.last_hit != 0:
		var attacker_name = "Unknown Killer"
		var attacker = get_node_or_null(str(player.last_hit))
		if attacker:
			attacker_name = attacker.nametag.text
		# Killfeed
		send_chat("[color=pink]" + attacker_name + "[img=24]res://assets/icons/sword.png[/img]" + player.nametag.text + "[/color]", false)
	else:
		# Suicide
		send_chat("[img=24]res://assets/icons/skull.png[/img]" + player.nametag.text, false)
	player.set_visible(false)
	player.freeze()

	# Respawn the player in 3 seconds
	get_tree().create_timer(3.0).timeout.connect(respawn_player.bind(peer_id))
