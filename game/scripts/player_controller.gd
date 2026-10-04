extends CharacterBody3D
signal health_changed(value: int)
signal ammo_changed(current: int, reserve: int)
signal died

const GRAVITY := 18.0
const WALK_SPEED := 5.2
const MAGAZINE_SIZE := 30
const DEFAULT_RELOAD_SECONDS := 2.25
const SHOT_INTERVAL := 0.105
const VIEWMODEL_POSITION := Vector3(0.025, -0.052, -0.015)
const VIEWMODEL_SCALE := 0.325
const VIEWMODEL_PATH := "res://vendor/viewmodel/scene.gltf"

var health := 100
var magazine := MAGAZINE_SIZE
var reserve_ammo := 120
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var pitch := 0.0
var recoil_pitch := 0.0
var shot_cooldown := 0.0
var reloading := false
var reload_timer := 0.0
var flash_timer := 0.0
var walk_bob_time := 0.0
var combat_audio: Node
var camera: Camera3D
var view_pivot: Node3D
var viewmodel_mount: Node3D
var viewmodel: Node3D
var viewmodel_anim: AnimationPlayer
var muzzle_flash: OmniLight3D
var anim_idle := ""
var anim_walk := ""
var anim_fire := ""
var anim_reload := ""
var animation_locked := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.8
	capsule.shape = shape
	capsule.position.y = 0.9
	add_child(capsule)

	view_pivot = Node3D.new()
	view_pivot.name = "View"
	view_pivot.position.y = 1.55
	add_child(view_pivot)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.fov = 76.0
	camera.near = 0.03
	view_pivot.add_child(camera)
	_build_viewmodel()

	_health_signal()
	_ammo_signal()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_viewmodel() -> void:
	viewmodel_mount = Node3D.new()
	viewmodel_mount.name = "ViewmodelMount"
	viewmodel_mount.position = VIEWMODEL_POSITION
	camera.add_child(viewmodel_mount)

	var packed := load(VIEWMODEL_PATH) as PackedScene
	if packed == null:
		push_error("Ready-made FPS viewmodel is missing: %s" % VIEWMODEL_PATH)
		return
	viewmodel = packed.instantiate() as Node3D
	if viewmodel == null:
		push_error("FPS viewmodel could not be instantiated")
		return
	viewmodel.name = "FPS_AK74M_Arms"
	viewmodel.scale = Vector3.ONE * VIEWMODEL_SCALE
	viewmodel.rotation.y = PI
	viewmodel_mount.add_child(viewmodel)

	viewmodel_anim = _find_animation_player(viewmodel)
	if viewmodel_anim:
		anim_idle = _resolve_animation(["Rig|AK_Idle", "ak_idle", "idle"])
		anim_walk = _resolve_animation(["Rig|AK_Walk", "ak_walk", "walk"])
		anim_fire = _resolve_animation(["Rig|AK_Shot", "ak_shot", "shot", "fire"])
		anim_reload = _resolve_animation(["Rig|AK_Reload_full", "reload_full", "reload"])
		viewmodel_anim.animation_finished.connect(_on_viewmodel_animation_finished)
		_play_locomotion_animation(true)
	else:
		push_error("FPS viewmodel has no AnimationPlayer")

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.position = Vector3(0.18, -0.05, -1.05)
	muzzle_flash.light_color = Color("ffbe72")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 2.8
	muzzle_flash.shadow_enabled = false
	viewmodel_mount.add_child(muzzle_flash)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _resolve_animation(candidates: Array) -> String:
	if not viewmodel_anim:
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
	if not viewmodel_anim or name.is_empty() or not viewmodel_anim.has_animation(StringName(name)):
		return 0.0
	var animation := viewmodel_anim.get_animation(StringName(name))
	return animation.length if animation else 0.0

func _play_animation(name: String, blend := 0.08, speed := 1.0, force := false) -> void:
	if not viewmodel_anim or name.is_empty():
		return
	if force or String(viewmodel_anim.current_animation) != name:
		viewmodel_anim.play(StringName(name), blend, speed)

func _play_locomotion_animation(force := false) -> void:
	if animation_locked or not viewmodel_anim:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.35 and not anim_walk.is_empty():
		_play_animation(anim_walk, 0.13, 1.0, force)
	elif not anim_idle.is_empty():
		_play_animation(anim_idle, 0.16, 1.0, force)

func _on_viewmodel_animation_finished(name: StringName) -> void:
	var finished := String(name)
	if finished == anim_fire or finished == anim_reload:
		animation_locked = false
		_play_locomotion_animation(true)

func _process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	recoil_pitch = move_toward(recoil_pitch, 0.0, delta * 0.12)
	view_pivot.rotation.x = pitch + recoil_pitch

	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and is_instance_valid(muzzle_flash):
			muzzle_flash.light_energy = 0.0

	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	_update_viewmodel_motion(delta)
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_just_pressed("fire"):
		request_fire()

func _update_viewmodel_motion(delta: float) -> void:
	if not is_instance_valid(viewmodel_mount):
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var move_strength := clampf(horizontal_speed / WALK_SPEED, 0.0, 1.0)
	if move_strength > 0.04 and is_on_floor():
		walk_bob_time += delta * 8.6
	var bob := Vector3.ZERO
	if not reloading:
		bob.x = sin(walk_bob_time) * 0.0045 * move_strength
		bob.y = abs(cos(walk_bob_time * 2.0)) * 0.004 * move_strength
	var target := VIEWMODEL_POSITION + bob
	viewmodel_mount.position = viewmodel_mount.position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
	_play_locomotion_animation()

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length() > 0.08:
		input_vec = touch_move
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var direction := (right * input_vec.x + forward * -input_vec.y).normalized()
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	if touch_look.length() > 0.0:
		add_touch_look(touch_look)
		touch_look = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative * 0.0022)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _apply_look(delta: Vector2) -> void:
	rotate_y(-delta.x)
	pitch = clampf(pitch - delta.y, -1.25, 1.25)

func set_touch_move(value: Vector2) -> void:
	touch_move = value.limit_length(1.0)

func add_touch_look(value: Vector2) -> void:
	_apply_look(value)

func request_fire() -> void:
	if health <= 0 or reloading or shot_cooldown > 0.0:
		return
	if magazine <= 0:
		reload()
		return
	magazine -= 1
	shot_cooldown = SHOT_INTERVAL
	recoil_pitch = maxf(recoil_pitch - 0.018, -0.055)
	animation_locked = true
	_play_animation(anim_fire, 0.02, 1.0, true)
	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = randf_range(1.8, 2.5)
	flash_timer = 0.045
	_ammo_signal()
	if is_instance_valid(combat_audio):
		combat_audio.call("play_player_shot", camera.global_position)

	var space := get_world_3d().direct_space_state
	var end := camera.global_position - camera.global_transform.basis.z * 120.0
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, end)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var collider = hit.get("collider")
		if collider and collider.has_method("take_damage"):
			collider.take_damage(34, hit.get("position", end), -camera.global_transform.basis.z)

func reload() -> void:
	if reloading or magazine >= MAGAZINE_SIZE or reserve_ammo <= 0 or health <= 0:
		return
	reloading = true
	var clip_length := _animation_length(anim_reload)
	reload_timer = clip_length if clip_length > 0.5 else DEFAULT_RELOAD_SECONDS
	animation_locked = true
	_play_animation(anim_reload, 0.08, 1.0, true)
	if is_instance_valid(combat_audio):
		combat_audio.call("play_reload", camera.global_position)

func _finish_reload() -> void:
	var needed: int = MAGAZINE_SIZE - magazine
	var loaded: int = mini(needed, reserve_ammo)
	magazine += loaded
	reserve_ammo -= loaded
	reloading = false
	reload_timer = 0.0
	animation_locked = false
	_ammo_signal()
	_play_locomotion_animation(true)

func take_damage(amount: int, _from: Vector3 = Vector3.ZERO) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_health_signal()
	if health == 0:
		died.emit()

func _health_signal() -> void:
	health_changed.emit(health)

func _ammo_signal() -> void:
	ammo_changed.emit(magazine, reserve_ammo)
