extends Node3D


@export var heal = 50


func _ready():
	if not is_multiplayer_authority(): return
	if not $RespawnTimer.is_stopped():
		visible = false
		$Area3D.set_deferred("monitoring", true)


func _on_area_3d_body_entered(hit_body):
	if not is_multiplayer_authority(): return
	# Heal
	if hit_body.has_method("receive_damage") and hit_body.get_multiplayer_authority() > 0:
		hit_body.set_health.rpc(hit_body.health + heal)
		$AudioStreamPlayer3D.play()
		visible = false
		$Area3D.set_deferred("monitoring", false)
		$RespawnTimer.start()


func _on_respawn_timer_timeout():
	if not is_multiplayer_authority(): return
	visible = true
	$Area3D.set_deferred("monitoring", true)
