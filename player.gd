extends CharacterBody3D

var rng = RandomNumberGenerator.new()

@export_range(1, 35, 1) var speed : float = 5 # m/s
@export_range(10, 400, 1) var acceleration : float = 25 # m/s^2
@export_range(10, 400, 1) var deceleration : float = 50 # m/s^2

@export_range(0.1, 3.0, 0.1) var jump_height : float = 2 # m
@export_range(10, 400, 1) var air_acceleration : float = 6 # m/s^2
@export_range(10, 400, 1) var air_deceleration : float = 6 # m/s^2

@export_range(0.1, 3.0, 0.1) var look_sensitivity : float = ProjectSettings.get_setting("gameplay/look_sensitivity")

@export_range(-PI/2, PI/2) var look_clamp_low = -PI/3
@export_range(-PI/2, PI/2) var look_clamp_high = PI/3

var jumping : bool

var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

var input_dir : Vector2 # Player input

var walk_vel : Vector3 # Walking velocity 
var grav_vel : Vector3 # Gravity velocity 
var jump_vel : Vector3 # Jumping velocity

@export var head_path:NodePath
@export var face_path:NodePath
@export var body_path:NodePath
@export var camera_path:NodePath
@export var animation_path:NodePath
@export var hand_animation_path:NodePath
@export var weapon_hitbox_path:NodePath
@export var weapon_audio_path:NodePath
@export var foot_audio_path:NodePath

@onready var head:Node3D = get_node(head_path)
@onready var face:MeshInstance3D = get_node(face_path)
@onready var body:MeshInstance3D = get_node(body_path)
@onready var camera:Camera3D = get_node(camera_path)
@onready var animation:AnimationPlayer = get_node(animation_path)
@onready var hand_animation:AnimationPlayer = get_node(hand_animation_path)
@onready var weapon_hitbox:Area3D = get_node(weapon_hitbox_path)
@onready var weapon_audio:AudioStreamPlayer3D = get_node(weapon_audio_path)
@onready var foot_audio:AudioStreamPlayer3D = get_node(foot_audio_path)

var sounds_env:Array = [
	preload("res://assets/sounds/swing_hit1.wav"),
	preload("res://assets/sounds/swing_hit3.wav"),
	preload("res://assets/sounds/swing_hit4.wav")
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

func _ready() -> void:
	capture_mouse(true)


func _unhandled_input(event : InputEvent) -> void:
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if event is InputEventMouseMotion: _aim(event)
	if Input.is_action_just_pressed("jump"): jumping = true
	if event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo(): capture_mouse(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
	# Attack
	if event.is_action("attack") and event.is_pressed() and not event.is_echo():
		if hand_animation.current_animation == "idle":
			hand_animation.stop()
			hand_animation.play("swing_h")
			weapon_audio.stream = sounds_swing_h[randi() % sounds_swing_h.size()]
			weapon_audio.pitch_scale = rng.randf_range(0.95, 1.05)
			weapon_audio.play()
	elif event.is_action("alt_attack") and event.is_pressed() and not event.is_echo():
		if hand_animation.current_animation == "idle":
			hand_animation.stop()
			hand_animation.play("swing_v")
			weapon_audio.stream = sounds_swing_v[randi() % sounds_swing_v.size()]
			weapon_audio.pitch_scale = rng.randf_range(0.95, 1.05)
			weapon_audio.play()
	elif event.is_action("alt2_attack") and event.is_pressed() and not event.is_echo():
		if hand_animation.current_animation == "idle":
			hand_animation.stop()
			hand_animation.play("jab")
			weapon_audio.stream = load("res://assets/sounds/swing_slow1.wav")
			weapon_audio.stream = sounds_jab[randi() % sounds_jab.size()]
			weapon_audio.pitch_scale = rng.randf_range(0.95, 1.05)
			weapon_audio.play()


func _physics_process(delta : float) -> void:
	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	move_and_slide()
	
	if not is_on_floor():
		if velocity.y < 0:
			animation.play("fall")
		elif animation.current_animation != "rise":
			animation.play("jump")
	elif is_on_floor() and not jumping:
		if animation.current_animation == "fall":
			footstep()
		if Vector2(velocity.x, velocity.z).length() > 0.01:
			animation.play("walk")
			var anim_speed = Vector2(velocity.x, velocity.z).length() / speed
			animation.speed_scale = anim_speed
		else:
			animation.play("RESET")
			animation.speed_scale = 1.0

	if camera.current:
		body.cast_shadow = body.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		face.cast_shadow = face.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		face.cast_shadow = body.SHADOW_CASTING_SETTING_ON
		face.cast_shadow = face.SHADOW_CASTING_SETTING_ON


func capture_mouse(capture : bool) -> void:
	if capture:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _aim(event : InputEvent) -> void:
	var mouse_axis : Vector2 = event.relative if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Vector2.ZERO
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


func _on_weapon_hitbox_body_entered(body):
	# Ignore self
	if body == self:
		return

	# Disable the hitbox
	weapon_hitbox.set_deferred("monitoring", false)
	
	# Play recoil animation to indicate a hit
	if hand_animation.current_animation == "swing_h":
		hand_animation.play("recoil_h")
	if hand_animation.current_animation == "swing_v":
		hand_animation.play("recoil_v")
	if hand_animation.current_animation == "jab":
		hand_animation.play("recoil_h")

	# Fade out the swing sound
	var tween = create_tween()
	tween.tween_property(weapon_audio, "volume_db", -80, 0.3)
	tween.tween_callback(weapon_audio.stop)
	tween.tween_property(weapon_audio, "volume_db", 0, 0)

	# Play a hit sound
	var hitsound = AudioStreamPlayer3D.new()
	self.get_parent().add_child(hitsound)
	hitsound.global_position = weapon_audio.global_position
	hitsound.stream = sounds_env[randi() % sounds_env.size()]
	hitsound.pitch_scale = rng.randf_range(0.95, 1.05)
	hitsound.play()
	hitsound.connect("finished", hitsound.queue_free)


func footstep():
	if is_on_floor():
		foot_audio.pitch_scale = rng.randf_range(0.95, 1.05)
		foot_audio.play()


