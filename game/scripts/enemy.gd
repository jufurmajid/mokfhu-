extends CharacterBody3D
signal died(enemy: Node3D)

const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const ENEMY_MODEL_PATH := "res://vendor/enemy/enemy.glb"
const MOVE_SPEED := 2.45

var player: Node3D
var combat_audio: Node
var health := 100
var shoot_timer := randf_range(1.0, 2.5)
var move_phase := randf() * TAU
var is_dead := false
var body_collision: CollisionShape3D
var visual_root: Node3D
var visual_model: Node3D
var animation_player: AnimationPlayer
var muzzle_flash: OmniLight3D
var flash_timer := 0.0
var animation_locked := false
var anim_idle := ""
var anim_run := ""
var anim_attack := ""
var anim_death := ""

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	body_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.78
	body_collision.shape = shape
	body_collision.position.y = 0.9
	add_child(body_collision)

	visual_root = Node3D.new()
	visual_root.name = "AnimatedSoldierVisual"
	add_child(visual_root)
	_build_soldier_visual()

func _build_soldier_visual() -> void:
	var packed := load(ENEMY_MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Animated enemy model is missing: %s" % ENEMY_MODEL_PATH)
		return
	visual_model = packed.instantiate() as Node3D
	if visual_model == null:
		push_error("Animated enemy model could not be instantiated")
		return
	visual_model.name = "VeteranSniper"
	visual_model.rotation.y = PI
	visual_root.add_child(visual_model)

	animation_player = _find_animation_player(visual_model)
	if animation_player:
		anim_idle = _resolve_animation(["idle", "stand"])
		anim_run = _resolve_animation(["run", "walk", "locomotion"])
		anim_attack = _resolve_animation(["attack_ranged", "ranged", "shoot", "fire", "attack"])
		anim_death = _resolve_animation(["death", "die", "dead"])
		animation_player.animation_finished.connect(_on_animation_finished)
		_play_animation(anim_idle, 0.0, 1.0, true)
	else:
		push_error("Animated enemy model has no AnimationPlayer")

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.position = Vector3(0.22, 1.25, -0.72)
	muzzle_flash.light_color = Color("ffb762")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 2.6
	muzzle_flash.shadow_enabled = false
	visual_root.add_child(muzzle_flash)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _resolve_animation(candidates: Array) -> String:
	if not animation_player:
		return ""
	var names := animation_player.get_animation_list()
	for candidate in candidates:
		var needle := String(candidate).to_lower()
		for name in names:
			if String(name).to_lower() == needle:
				return String(name)
	for candidate in candidates:
		var needle := String(candidate).to_lower()
		for name in names:
			if String(name).to_lower().contains(needle):
				return String(name)
	return ""

func _play_animation(name: String, blend := 0.12, speed := 1.0, force := false) -> void:
	if not animation_player or name.is_empty():
		return
	if force or String(animation_player.current_animation) != name:
		animation_player.play(StringName(name), blend, speed)

func _on_animation_finished(name: StringName) -> void:
	var finished := String(name)
	if finished == anim_attack:
		animation_locked = false
		_update_locomotion_animation(true)
	elif finished == anim_death:
		animation_locked = true

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and is_instance_valid(muzzle_flash):
			muzzle_flash.light_energy = 0.0
	if not is_dead:
		_update_locomotion_animation()

func _update_locomotion_animation(force := false) -> void:
	if animation_locked or not animation_player:
		return
	var move_speed := Vector2(velocity.x, velocity.z).length()
	if move_speed > 0.18 and not anim_run.is_empty():
		_play_animation(anim_run, 0.16, 1.05, force)
	elif not anim_idle.is_empty():
		_play_animation(anim_idle, 0.18, 1.0, force)

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or int(player.get("health")) <= 0:
		return
	shoot_timer -= delta
	var to_player: Vector3 = player.global_position - global_position
	var distance := to_player.length()
	var flat := Vector3(to_player.x, 0.0, to_player.z).normalized()

	if distance > 12.0:
		velocity.x = flat.x * MOVE_SPEED
		velocity.z = flat.z * MOVE_SPEED
	else:
		move_phase += delta * 0.85
		var strafe := Vector3(-flat.z, 0.0, flat.x) * sin(move_phase) * 1.0
		velocity.x = strafe.x
		velocity.z = strafe.z

	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.15
	move_and_slide()

	if shoot_timer <= 0.0 and distance < 52.0:
		_fire_at_player()
		shoot_timer = randf_range(1.35, 2.45)

func _fire_at_player() -> void:
	var muzzle := global_position + Vector3(0, 1.28, 0) - global_transform.basis.z * 0.62
	if is_instance_valid(combat_audio):
		combat_audio.call("play_enemy_shot", muzzle, player.global_position)
	if not anim_attack.is_empty():
		animation_locked = true
		_play_animation(anim_attack, 0.07, 1.0, true)
	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = randf_range(1.0, 1.55)
	flash_timer = 0.055

	var projectile := Node3D.new()
	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.position = muzzle
	projectile.target = player.global_position + Vector3(0, 1.1, 0)
	projectile.player = player
	projectile.combat_audio = combat_audio
	get_tree().current_scene.add_child(projectile)

func take_damage(amount: int, _hit_position: Vector3, _hit_direction: Vector3) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	animation_locked = true
	if not anim_death.is_empty():
		_play_animation(anim_death, 0.08, 1.0, true)
	else:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(visual_root, "rotation", Vector3(0.0, 0.0, deg_to_rad(86.0)), 0.48)
		tween.parallel().tween_property(visual_root, "position:y", 0.14, 0.48)
	var cleanup := get_tree().create_timer(7.0)
	cleanup.timeout.connect(queue_free)
	died.emit(self)
