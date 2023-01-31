extends CharacterBody3D

@export_range(1, 35, 1) var speed : float = 5 # m/s
@export_range(0, 400, 1) var acceleration : float = 25 # m/s^2
@export_range(0, 400, 1) var deceleration : float = 50 # m/s^2

@export_range(0.1, 3.0, 0.1) var jump_height : float = 2 # m
@export_range(0, 400, 1) var air_acceleration : float = 6 # m/s^2
@export_range(0, 400, 1) var air_deceleration : float = 6 # m/s^2

@export_range(-PI/2, PI/2) var look_clamp_low = -PI/3
@export_range(-PI/2, PI/2) var look_clamp_high = PI/3

var jumping : bool

var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

var input_dir : Vector2 # Player input

var walk_vel : Vector3 # Walking velocity 
var grav_vel : Vector3 # Gravity velocity 
var jump_vel : Vector3 # Jumping velocity

var health : float = 100.0
var max_health : float = 100.0

var last_hit = null

signal health_changed(value)

@onready var head:Node3D = $HeadPivot
@onready var head_shape:MeshInstance3D = $HeadPivot/Head
@onready var face:MeshInstance3D = $HeadPivot/Face
@onready var body:MeshInstance3D = $WaistPivot/Body
@onready var hand:MeshInstance3D = $HeadPivot/SwingPivot/HandPivot/HandModel
@onready var camera:Camera3D = $HeadPivot/CameraFirstPerson
@onready var animation:AnimationPlayer = $AnimationPlayer
@onready var hand_animation:AnimationPlayer = $HeadPivot/SwingPivot/HandPivot/HandAnimation
@onready var weapon_hitbox:Area3D = $HeadPivot/SwingPivot/HandPivot/WeaponStick/WeaponHitbox
@onready var weapon_audio:AudioStreamPlayer3D = $HeadPivot/SwingPivot/HandPivot/WeaponStick/AudioStreamPlayer3D
@onready var foot_audio:AudioStreamPlayer3D = $FootPlayer
@onready var invincible_timer:Timer = $InvincibleTimer
@onready var collision_shape:CollisionShape3D = $CollisionShape3D
@onready var nametag:Label3D = $NameTag

var sounds_env:Array = [
	preload("res://assets/sounds/swing_hit1.wav"),
	preload("res://assets/sounds/swing_hit2.wav"),
	preload("res://assets/sounds/swing_hit3.wav"),
	preload("res://assets/sounds/swing_hit4.wav"),
	preload("res://assets/sounds/swing_hit5.wav")
]
var sounds_player:Array = [
	preload("res://assets/sounds/hit_player1.wav"),
	preload("res://assets/sounds/hit_player2.wav"),
	preload("res://assets/sounds/hit_player3.wav"),
]
var sounds_player_death:Array = [
	preload("res://assets/sounds/blunt_death.wav"),
]
var sounds_swing_h:Array = [
	preload("res://assets/sounds/swing_fast1.wav"),
	preload("res://assets/sounds/swing_fast2.wav")
]
var sounds_swing_v:Array = [
	preload("res://assets/sounds/swing_med1.wav"),
	preload("res://assets/sounds/swing_med2.wav")
]
var sounds_jab:Array = [preload("res://assets/sounds/swing_slow1.wav")]


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	colorize()
	if not is_multiplayer_authority(): return
	camera.set_current(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event : InputEvent) -> void:
	if not is_multiplayer_authority(): return

	# Mouselook is epic
	if event is InputEventMouseMotion: _aim(event)

	# we're too dead to process any movement
	if health <= 0: return

	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if event.is_action("jump") and event.is_pressed() and not event.is_echo(): jumping = true
	# Attack
	if event.is_action("attack") and event.is_pressed() and not event.is_echo():
		if hand_animation.current_animation == "idle":
			attack.rpc()
	elif event.is_action("alt_attack") and event.is_pressed() and not event.is_echo():
		if hand_animation.current_animation == "idle":
			alt_attack.rpc()
	elif event.is_action("alt2_attack") and event.is_pressed() and not event.is_echo():
		if hand_animation.current_animation == "idle":
			alt2_attack.rpc()


func _physics_process(delta : float) -> void:
	$SpawnShield.visible = not invincible_timer.is_stopped()
	if not is_multiplayer_authority(): return
	# we're too dead to do any physics
	if health <= 0: return

	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	move_and_slide()
	
	if not is_on_floor():
		if velocity.y < 0:
			play_anim.rpc("fall")
		elif animation.current_animation != "rise":
			play_anim.rpc("jump")
	elif is_on_floor() and not jumping:
		if animation.current_animation == "fall":
			footstep()
		if Vector2(velocity.x, velocity.z).length() > 0.01:
			var anim_speed = Vector2(velocity.x, velocity.z).length() / speed
			play_anim.rpc("walk", anim_speed)
		else:
			play_anim.rpc("RESET", 1.0)

	if camera.current:
		body.cast_shadow = body.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		face.cast_shadow = face.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		hand.cast_shadow = hand.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		body.cast_shadow = body.SHADOW_CASTING_SETTING_ON
		face.cast_shadow = face.SHADOW_CASTING_SETTING_ON
		hand.cast_shadow = hand.SHADOW_CASTING_SETTING_ON


func _aim(event : InputEvent) -> void:
	var mouse_axis : Vector2 = event.relative if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Vector2.ZERO
	var look_sensitivity = ProjectSettings.get_setting("gameplay/look_sensitivity")
	self.rotation.y -= mouse_axis.x * look_sensitivity * .001
	head.rotation.x = clamp(head.rotation.x - mouse_axis.y * look_sensitivity * .001, -1.5, 1.5)


func _walk(delta : float) -> Vector3:
	var acc = acceleration
	var dec = deceleration
	if not is_on_floor():
		acc = air_acceleration
		dec = air_deceleration
	if input_dir:
		var camera_dir : Vector3 = camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
		walk_vel = walk_vel.move_toward(Vector3(camera_dir.x, 0, camera_dir.z).normalized() * speed, acc * delta)
	else:
		walk_vel = walk_vel.move_toward(Vector3.ZERO, dec * delta)
	return walk_vel


func _gravity(delta : float) -> Vector3:
	grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta)
	return grav_vel


func _jump(delta : float) -> Vector3:
	if jumping:
		jumping = false; if is_on_floor(): jump_vel = Vector3(0, sqrt(4 * jump_height * gravity), 0)
	else:
		jump_vel = Vector3.ZERO if is_on_floor() else jump_vel.move_toward(Vector3.ZERO, gravity * delta)
	return jump_vel


func _on_hand_animation_animation_finished(anim_name):
	if anim_name == "swing_h" or anim_name == "swing_v" or anim_name == "jab" or anim_name == "recoil_h" or anim_name == "recoil_v":
		hand_animation.play("idle")


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "fall_transition":
		animation.play("fall")
	if anim_name == "jump":
		animation.play("rise")


func _on_weapon_hitbox_body_entered(hit_body):
	if not is_multiplayer_authority(): return

	# we're too dead to deal any damage
	if health <= 0: return

	# Ignore self
	if hit_body == self:
		return

	# Disable the hitbox
	weapon_hitbox.set_deferred("monitoring", false)
	
	var dmg_amount = 0
	
	# Play recoil animation to indicate a hit
	if hand_animation.current_animation == "swing_h":
		dmg_amount = 45
		recoil1.rpc()
	if hand_animation.current_animation == "swing_v":
		dmg_amount = 45
		recoil2.rpc()
	if hand_animation.current_animation == "jab":
		dmg_amount = 35
		recoil1.rpc()

	# Damage
	if hit_body.has_method("receive_damage") and hit_body.get_multiplayer_authority() > 0 and hit_body.get_multiplayer_authority() != multiplayer.get_unique_id():
		if not hit_body.invincible_timer.is_stopped():
			return
		if hit_body.health <= dmg_amount:
			hitsound_murder.rpc()
		else:
			hitsound_harm.rpc()
		hit_body.receive_damage.rpc(dmg_amount, multiplayer.get_unique_id())
	else:
		hitsound_env.rpc()


func footstep():
	if not is_multiplayer_authority(): return

	if is_on_floor():
		footstep_sound.rpc()


@rpc("call_local")
func footstep_sound():
	foot_audio.pitch_scale = randf_range(0.95, 1.05)
	foot_audio.play()


@rpc("call_local")
func play_anim(anim, speed_scale=1.0):
	animation.play(anim)
	animation.speed_scale = speed_scale


@rpc("call_local")
func attack():
	hand_animation.stop()
	hand_animation.play("swing_h")
	weapon_audio.stream = sounds_swing_h[randi() % sounds_swing_h.size()]
	weapon_audio.pitch_scale = randf_range(0.95, 1.05)
	weapon_audio.play()


@rpc("call_local")
func alt_attack():
	hand_animation.stop()
	hand_animation.play("swing_v")
	weapon_audio.stream = sounds_swing_v[randi() % sounds_swing_v.size()]
	weapon_audio.pitch_scale = randf_range(0.95, 1.05)
	weapon_audio.play()


@rpc("call_local")
func alt2_attack():
	hand_animation.stop()
	hand_animation.play("jab")
	weapon_audio.stream = load("res://assets/sounds/swing_slow1.wav")
	weapon_audio.stream = sounds_jab[randi() % sounds_jab.size()]
	weapon_audio.pitch_scale = randf_range(0.95, 1.05)
	weapon_audio.play()


@rpc("call_local")
func recoil1():
	hand_animation.play("recoil_h")

	# Fade out the swing sound
	var tween = create_tween()
	tween.tween_property(weapon_audio, "volume_db", -80, 0.3)
	tween.tween_callback(weapon_audio.stop)
	tween.tween_property(weapon_audio, "volume_db", 0, 0)


@rpc("call_local")
func recoil2():
	hand_animation.play("recoil_v")

	# Fade out the swing sound
	var tween = create_tween()
	tween.tween_property(weapon_audio, "volume_db", -80, 0.3)
	tween.tween_callback(weapon_audio.stop)
	tween.tween_property(weapon_audio, "volume_db", 0, 0)


@rpc("call_local")
func hitsound_env():
	var hitsound = AudioStreamPlayer3D.new()
	self.get_parent().add_child(hitsound)
	hitsound.global_position = weapon_audio.global_position
	hitsound.stream = sounds_env[randi() % sounds_env.size()]
	hitsound.pitch_scale = randf_range(0.95, 1.05)
	hitsound.play()
	hitsound.connect("finished", hitsound.queue_free)


@rpc("call_local")
func hitsound_harm():
	var hitsound = AudioStreamPlayer3D.new()
	self.get_parent().add_child(hitsound)
	hitsound.global_position = weapon_audio.global_position
	hitsound.stream = sounds_player[randi() % sounds_player.size()]
	hitsound.pitch_scale = randf_range(0.95, 1.05)
	hitsound.play()
	hitsound.connect("finished", hitsound.queue_free)


@rpc("call_local")
func hitsound_murder():
	var hitsound = AudioStreamPlayer3D.new()
	self.get_parent().add_child(hitsound)
	hitsound.global_position = weapon_audio.global_position
	hitsound.stream = sounds_player_death[randi() % sounds_player_death.size()]
	hitsound.pitch_scale = randf_range(0.95, 1.05)
	hitsound.play()
	hitsound.connect("finished", hitsound.queue_free)


@rpc("any_peer", "call_local")
func receive_damage(amt, source_id = 0):
	last_hit = source_id
	health -= amt
	health_changed.emit(health)


@rpc("any_peer", "call_local")
func set_health(amt):
	health = amt
	health_changed.emit(health)


@rpc("any_peer", "call_local")
func invincibility(amt):
	invincible_timer.start(amt)


func freeze():
	axis_lock_linear_x = true
	axis_lock_linear_y = true
	axis_lock_linear_z = true
	collision_shape.disabled = true


func unfreeze():
	axis_lock_linear_x = false
	axis_lock_linear_y = false
	axis_lock_linear_z = false
	collision_shape.disabled = false


func colorize():
	var face_color = stringToColor(name)
	var head_color = stringToColor(name, face_color)
	
	var color_mat = StandardMaterial3D.new()
	color_mat.albedo_color = face_color
	face.set_surface_override_material(0, color_mat)

	var color_mat_2 = StandardMaterial3D.new()
	color_mat_2.albedo_color = head_color
	head_shape.set_surface_override_material(0, color_mat_2)
	body.set_surface_override_material(0, color_mat_2)
	hand.set_surface_override_material(0, color_mat_2)
	$WaistPivot/RightButt/RightFoot/RightFootMesh.set_surface_override_material(0, color_mat_2)
	$WaistPivot/LeftButt/LeftFoot/LeftFootMesh.set_surface_override_material(0, color_mat_2)


func stringToColor(string, mix = Color.WHITE, mixcoeff = 0.5):
	var color = Color(string.hash() & 0xffffff)

	# mix the color
	if (mix != null):
		color.r = color.r * (1 - mixcoeff) + mix.r * mixcoeff
		color.g = color.g * (1 - mixcoeff) + mix.g * mixcoeff
		color.b = color.b * (1 - mixcoeff) + mix.b * mixcoeff

	return color
