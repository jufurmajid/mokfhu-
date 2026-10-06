extends CharacterBody3D

signal ammo_changed(current: int, reserve: int)
signal viewmodel_tuning_changed(position: Vector3, scale: float, fov: float)

const GRAVITY := 18.0
const WALK_SPEED := 5.0
const CROUCH_SPEED := 3.2
const JUMP_VELOCITY := 6.2
const MAGAZINE_SIZE := 30
const SHOT_INTERVAL := 0.105
const DEFAULT_RELOAD_SECONDS := 2.25

const BASE_FOV := 78.0
const ADS_FOV := 64.0
const STANDING_EYE_HEIGHT := 1.55
const CROUCH_EYE_HEIGHT := 1.08
const LOOK_SENSITIVITY := 0.00215
const ADS_LOOK_MULTIPLIER := 0.72

const VIEWMODEL_PATH := "res://vendor/viewmodel/scene.gltf"
const VIEWMODEL_HIP_POSITION := Vector3(0.16, -0.18, -0.56)
const VIEWMODEL_ADS_POSITION := Vector3(0.055, -0.135, -0.47)
const VIEWMODEL_SCALE := 0.155
const VIEWMODEL_ROTATION_DEGREES := Vector3(-3.0, 180.0, 1.0)

const PLAYER_SHOT = preload("res://assets/audio/صوت سلاح الاعب .ogg")
const RELOAD_CLICK = preload("res://assets/audio/reload_click.wav")

var magazine := MAGAZINE_SIZE
var reserve_ammo := 120
var touch_move := Vector2.ZERO
var pitch := 0.0
var shot_cooldown := 0.0
var reloading := false
var reload_timer := 0.0
var animation_locked := false
var aiming := false
var crouched := false
var walk_bob_time := 0.0
var weapon_kick := 0.0

var tuning_mode := false
var tuned_hip_position: Vector3 = VIEWMODEL_HIP_POSITION
var tuned_ads_position: Vector3 = VIEWMODEL_ADS_POSITION
var tuned_scale: float = VIEWMODEL_SCALE
var tuned_fov: float = BASE_FOV

var camera: Camera3D
var view_pivot: Node3D
var viewmodel_mount: Node3D
var viewmodel: Node3D
var viewmodel_anim: AnimationPlayer
var muzzle_flash: OmniLight3D
var shot_audio: AudioStreamPlayer
var reload_audio: AudioStreamPlayer
var body_collision: CollisionShape3D
var capsule_shape: CapsuleShape3D

var anim_idle := ""
var anim_walk := ""
var anim_fire := ""
var anim_reload := ""

func _ready() -> void:
	_build_collision()
	_build_camera()
	_build_viewmodel()
	_build_audio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("emit_tuning_state")

func _build_collision() -> void:
	body_collision = CollisionShape3D.new()
	body_collision.name = "PlayerCollision"
	capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.38
	capsule_shape.height = 1.8
	body_collision.shape = capsule_shape
	body_collision.position.y = 0.9
	add_child(body_collision)

func _build_camera() -> void:
	view_pivot = Node3D.new()
	view_pivot.name = "View"
	view_pivot.position.y = STANDING_EYE_HEIGHT
	add_child(view_pivot)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.fov = tuned_fov
	camera.near = 0.02
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	view_pivot.add_child(camera)

func _build_viewmodel() -> void:
	viewmodel_mount = Node3D.new()
	viewmodel_mount.name = "ViewmodelMount"
	viewmodel_mount.position = tuned_hip_position
	camera.add_child(viewmodel_mount)

	var packed := load(VIEWMODEL_PATH) as PackedScene
	if packed == null:
		push_error("MOKFHU_FATAL: AK hands viewmodel is missing")
		return
	viewmodel = packed.instantiate() as Node3D
	if viewmodel == null:
		push_error("MOKFHU_FATAL: AK hands viewmodel could not instantiate")
		return
	viewmodel.name = "FPS_AK74M_Arms"
	viewmodel.scale = Vector3.ONE * tuned_scale
	viewmodel.rotation_degrees = VIEWMODEL_ROTATION_DEGREES
	viewmodel_mount.add_child(viewmodel)

	viewmodel_anim = _find_animation_player(viewmodel)
	if viewmodel_anim == null:
		push_error("MOKFHU_FATAL: AK hands viewmodel has no AnimationPlayer")
		return

	anim_idle = _resolve_animation(["Rig|AK_Idle", "idle"])
	anim_walk = _resolve_animation(["Rig|AK_Walk", "walk"])
	anim_fire = _resolve_animation(["Rig|AK_Shot", "shot", "fire"])
	anim_reload = _resolve_animation(["Rig|AK_Reload_full", "reload"])
	viewmodel_anim.animation_finished.connect(_on_animation_finished)
	_play_locomotion(true)

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.position = Vector3(0.13, -0.06, -0.86)
	muzzle_flash.light_color = Color("ffc078")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 2.5
	muzzle_flash.shadow_enabled = false
	viewmodel_mount.add_child(muzzle_flash)

func _build_audio() -> void:
	shot_audio = AudioStreamPlayer.new()
	shot_audio.name = "PlayerShot"
	shot_audio.stream = PLAYER_SHOT
	shot_audio.volume_db = 0.0
	add_child(shot_audio)

	reload_audio = AudioStreamPlayer.new()
	reload_audio.name = "Reload"
	reload_audio.stream = RELOAD_CLICK
	reload_audio.volume_db = -2.0
	add_child(reload_audio)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _resolve_animation(candidates: Array) -> String:
	if viewmodel_anim == null:
		return ""
	var names := viewmodel_anim.get_animation_list()
	for candidate in candidates:
		for name in names:
			if String(name) == String(candidate):
				return String(name)
	for candidate in candidates:
		var needle := String(candidate).to_lower()
		for name in names:
			if String(name).to_lower().contains(needle):
				return String(name)
	return ""

func _animation_length(name: String) -> float:
	if viewmodel_anim == null or name.is_empty() or not viewmodel_anim.has_animation(StringName(name)):
		return 0.0
	var animation := viewmodel_anim.get_animation(StringName(name))
	return animation.length if animation != null else 0.0

func _play_animation(name: String, blend := 0.08, speed := 1.0, force := false) -> void:
	if viewmodel_anim == null or name.is_empty():
		return
	if force or String(viewmodel_anim.current_animation) != name:
		viewmodel_anim.play(StringName(name), blend, speed)

func _play_locomotion(force := false) -> void:
	if animation_locked or viewmodel_anim == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.35 and not anim_walk.is_empty():
		_play_animation(anim_walk, 0.12, 1.0, force)
	elif not anim_idle.is_empty():
		_play_animation(anim_idle, 0.16, 1.0, force)

func _on_animation_finished(name: StringName) -> void:
	var finished := String(name)
	if finished == anim_fire or finished == anim_reload:
		animation_locked = false
		_play_locomotion(true)

func _process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	weapon_kick = move_toward(weapon_kick, 0.0, delta * 0.22)

	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	var target_fov := ADS_FOV if aiming else tuned_fov
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 10.0, 0.0, 1.0))

	var eye_height := CROUCH_EYE_HEIGHT if crouched else STANDING_EYE_HEIGHT
	view_pivot.position.y = lerpf(view_pivot.position.y, eye_height, clampf(delta * 12.0, 0.0, 1.0))

	_update_viewmodel(delta)
	_play_locomotion()

	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_just_pressed("fire"):
		request_fire()
	if Input.is_action_just_pressed("jump"):
		request_jump()
	if Input.is_action_just_pressed("crouch"):
		toggle_crouch()
	if Input.is_action_just_pressed("aim"):
		set_aiming(not aiming)

func _update_viewmodel(delta: float) -> void:
	if viewmodel_mount == null:
		return

	var target := tuned_ads_position if aiming else tuned_hip_position
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var move_amount := clampf(horizontal_speed / WALK_SPEED, 0.0, 1.0)

	if move_amount > 0.05 and is_on_floor():
		walk_bob_time += delta * (6.0 if aiming else 8.0)

	if not tuning_mode and not aiming and not reloading:
		target.x += sin(walk_bob_time) * 0.0035 * move_amount
		target.y += abs(cos(walk_bob_time * 2.0)) * 0.0025 * move_amount

	if not tuning_mode:
		target.z += weapon_kick
	viewmodel_mount.position = viewmodel_mount.position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))

func _physics_process(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length() > 0.08:
		input_vec = touch_move

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var direction := (right * input_vec.x + forward * -input_vec.y).normalized()
	var move_speed := CROUCH_SPEED if crouched else WALK_SPEED
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative * LOOK_SENSITIVITY)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _apply_look(delta_value: Vector2) -> void:
	var multiplier := ADS_LOOK_MULTIPLIER if aiming else 1.0
	rotate_y(-delta_value.x * multiplier)
	pitch = clampf(pitch - delta_value.y * multiplier, -1.25, 1.25)
	view_pivot.rotation.x = pitch

func set_touch_move(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

func add_touch_look(value: Vector2) -> void:
	_apply_look(value)

func set_aiming(active: bool) -> void:
	aiming = active

func toggle_crouch() -> void:
	crouched = not crouched
	if capsule_shape != null and body_collision != null:
		if crouched:
			capsule_shape.height = 1.24
			body_collision.position.y = 0.62
		else:
			capsule_shape.height = 1.8
			body_collision.position.y = 0.9

func request_jump() -> void:
	if crouched:
		return
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func request_fire() -> void:
	if reloading or shot_cooldown > 0.0:
		return
	if magazine <= 0:
		reload()
		return

	magazine -= 1
	shot_cooldown = SHOT_INTERVAL
	weapon_kick = 0.018 if aiming else 0.028
	animation_locked = true
	_play_animation(anim_fire, 0.02, 1.0, true)

	if shot_audio != null:
		shot_audio.pitch_scale = randf_range(0.985, 1.015)
		shot_audio.play()

	if muzzle_flash != null:
		muzzle_flash.light_energy = 2.0
		get_tree().create_timer(0.045).timeout.connect(func():
			if is_instance_valid(muzzle_flash):
				muzzle_flash.light_energy = 0.0
		)

	emit_ammo()

func reload() -> void:
	if reloading or magazine >= MAGAZINE_SIZE or reserve_ammo <= 0:
		return

	reloading = true
	var length := _animation_length(anim_reload)
	reload_timer = length if length > 0.5 else DEFAULT_RELOAD_SECONDS
	animation_locked = true
	_play_animation(anim_reload, 0.08, 1.0, true)

	if reload_audio != null:
		reload_audio.play()

func _finish_reload() -> void:
	var needed := MAGAZINE_SIZE - magazine
	var loaded := mini(needed, reserve_ammo)
	magazine += loaded
	reserve_ammo -= loaded
	reloading = false
	reload_timer = 0.0
	animation_locked = false
	emit_ammo()
	_play_locomotion(true)

func set_tuning_mode(active: bool) -> void:
	tuning_mode = active
	if active:
		aiming = false
		weapon_kick = 0.0
		if viewmodel_mount != null:
			viewmodel_mount.position = tuned_hip_position
		if camera != null:
			camera.fov = tuned_fov
	emit_tuning_state()

func adjust_viewmodel_axis(axis: String, amount: float) -> void:
	var delta := Vector3.ZERO
	match axis:
		"x":
			delta.x = amount
		"y":
			delta.y = amount
		"z":
			delta.z = amount
		_:
			return

	tuned_hip_position += delta
	tuned_ads_position += delta

	tuned_hip_position.x = clampf(tuned_hip_position.x, -0.40, 0.55)
	tuned_hip_position.y = clampf(tuned_hip_position.y, -0.55, 0.20)
	tuned_hip_position.z = clampf(tuned_hip_position.z, -1.20, -0.16)
	tuned_ads_position.x = clampf(tuned_ads_position.x, -0.45, 0.45)
	tuned_ads_position.y = clampf(tuned_ads_position.y, -0.55, 0.20)
	tuned_ads_position.z = clampf(tuned_ads_position.z, -1.20, -0.12)

	if tuning_mode and viewmodel_mount != null:
		viewmodel_mount.position = tuned_hip_position
	emit_tuning_state()

func adjust_viewmodel_scale(amount: float) -> void:
	tuned_scale = clampf(tuned_scale + amount, 0.08, 0.30)
	if viewmodel != null:
		viewmodel.scale = Vector3.ONE * tuned_scale
	emit_tuning_state()

func adjust_camera_fov(amount: float) -> void:
	tuned_fov = clampf(tuned_fov + amount, 60.0, 100.0)
	if camera != null and not aiming:
		camera.fov = tuned_fov
	emit_tuning_state()

func reset_viewmodel_tuning() -> void:
	tuned_hip_position = VIEWMODEL_HIP_POSITION
	tuned_ads_position = VIEWMODEL_ADS_POSITION
	tuned_scale = VIEWMODEL_SCALE
	tuned_fov = BASE_FOV
	if viewmodel != null:
		viewmodel.scale = Vector3.ONE * tuned_scale
	if viewmodel_mount != null:
		viewmodel_mount.position = tuned_hip_position
	if camera != null and not aiming:
		camera.fov = tuned_fov
	emit_tuning_state()

func emit_tuning_state() -> void:
	viewmodel_tuning_changed.emit(tuned_hip_position, tuned_scale, tuned_fov)

func emit_ammo() -> void:
	ammo_changed.emit(magazine, reserve_ammo)
