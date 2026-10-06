extends CharacterBody3D

signal died(enemy: Node3D)

const ENEMY_AIM_MODEL_PATH := "res://vendor/enemy/assault_aim.glb"
const ENEMY_RUN_MODEL_PATH := "res://vendor/enemy/assault_run.glb"

const MOVE_SPEED := 2.15
const SOLDIER_HEIGHT := 1.78
const MAX_HEALTH := 100
const GRAVITY := 18.0

var player: Node3D
var combat_audio: Node
var health := MAX_HEALTH
var shoot_timer := randf_range(0.9, 1.8)
var move_phase := randf() * TAU
var is_dead := false
var body_collision: CollisionShape3D
var visual_root: Node3D
var aim_visual: Node3D
var run_visual: Node3D
var muzzle_flash: OmniLight3D
var flash_timer := 0.0
var pose_lock_timer := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_build_collision()
	_build_visual()

func _build_collision() -> void:
	body_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.80
	body_collision.shape = shape
	body_collision.position.y = 0.90
	add_child(body_collision)

func _build_visual() -> void:
	var aim_packed := load(ENEMY_AIM_MODEL_PATH) as PackedScene
	var run_packed := load(ENEMY_RUN_MODEL_PATH) as PackedScene
	if aim_packed == null or run_packed == null:
		push_error("MOKFHU_FATAL: enemy GLB assets are missing")
		return

	visual_root = Node3D.new()
	visual_root.name = "TacticalSoldierVisual"
	add_child(visual_root)

	aim_visual = aim_packed.instantiate() as Node3D
	run_visual = run_packed.instantiate() as Node3D
	if aim_visual == null or run_visual == null:
		push_error("MOKFHU_FATAL: enemy GLB assets could not instantiate")
		return

	for model in [aim_visual, run_visual]:
		model.rotation.y = PI
		visual_root.add_child(model)
		_normalize_model(model)

	aim_visual.name = "AimPose"
	run_visual.name = "RunPose"
	_set_running_pose(false)

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "EnemyMuzzleFlash"
	muzzle_flash.position = Vector3(0.06, 1.35, -0.70)
	muzzle_flash.light_color = Color("ffb66b")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 1.8
	muzzle_flash.shadow_enabled = false
	visual_root.add_child(muzzle_flash)

func _model_bounds(root: Node3D) -> AABB:
	var found := false
	var minimum := Vector3(1000000.0, 1000000.0, 1000000.0)
	var maximum := Vector3(-1000000.0, -1000000.0, -1000000.0)
	var mesh_nodes := root.find_children("*", "MeshInstance3D", true, false)
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var box := mesh_instance.get_aabb()
		var relative := Transform3D.IDENTITY
		var current: Node = mesh_instance
		while current != null and current != root:
			if current is Node3D:
				relative = (current as Node3D).transform * relative
			current = current.get_parent()
		for xi in range(2):
			for yi in range(2):
				for zi in range(2):
					var local_point := box.position + Vector3(box.size.x * xi, box.size.y * yi, box.size.z * zi)
					var point: Vector3 = relative * local_point
					minimum.x = minf(minimum.x, point.x)
					minimum.y = minf(minimum.y, point.y)
					minimum.z = minf(minimum.z, point.z)
					maximum.x = maxf(maximum.x, point.x)
					maximum.y = maxf(maximum.y, point.y)
					maximum.z = maxf(maximum.z, point.z)
					found = true
	if not found:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return AABB(minimum, maximum - minimum)

func _normalize_model(model: Node3D) -> void:
	var bounds := _model_bounds(model)
	if bounds.size.y <= 0.001:
		push_error("MOKFHU_FATAL: enemy model contains no visible mesh")
		return
	var factor := SOLDIER_HEIGHT / bounds.size.y
	model.scale = Vector3.ONE * factor
	var center_x := bounds.position.x + bounds.size.x * 0.5
	var center_z := bounds.position.z + bounds.size.z * 0.5
	model.position = Vector3(-center_x * factor, -bounds.position.y * factor, -center_z * factor)

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and is_instance_valid(muzzle_flash):
			muzzle_flash.light_energy = 0.0

	if pose_lock_timer > 0.0:
		pose_lock_timer -= delta
	elif not is_dead:
		_set_running_pose(Vector2(velocity.x, velocity.z).length() > 0.25)

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player):
		return
	if not bool(player.get("alive")):
		velocity = Vector3.ZERO
		return

	shoot_timer -= delta
	var target_position := player.global_position + Vector3(0.0, 1.15, 0.0)
	var to_player := target_position - (global_position + Vector3(0.0, 1.15, 0.0))
	var distance := to_player.length()
	var flat := Vector3(to_player.x, 0.0, to_player.z).normalized()

	if distance > 15.0:
		velocity.x = flat.x * MOVE_SPEED
		velocity.z = flat.z * MOVE_SPEED
	elif distance < 7.0:
		velocity.x = -flat.x * MOVE_SPEED * 0.65
		velocity.z = -flat.z * MOVE_SPEED * 0.65
	else:
		move_phase += delta * 1.15
		var side := Vector3(-flat.z, 0.0, flat.x)
		var strafe := side * sin(move_phase) * MOVE_SPEED * 0.58
		velocity.x = strafe.x
		velocity.z = strafe.z

	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.12
	move_and_slide()

	if shoot_timer <= 0.0 and distance < 44.0 and _has_line_of_sight():
		_fire(distance)
		shoot_timer = randf_range(1.15, 2.0)

func _has_line_of_sight() -> bool:
	if get_world_3d() == null or not is_instance_valid(player):
		return false
	var from := global_position + Vector3(0.0, 1.35, 0.0)
	var to := player.global_position + Vector3(0.0, 1.20, 0.0)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == player

func _fire(distance: float) -> void:
	pose_lock_timer = 0.28
	_set_running_pose(false)
	var muzzle := global_position + Vector3(0.0, 1.34, 0.0) - global_transform.basis.z * 0.70

	if is_instance_valid(combat_audio):
		combat_audio.call("play_enemy_shot", muzzle, player.global_position)

	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = randf_range(0.8, 1.2)
		flash_timer = 0.045

	var accuracy := clampf(0.78 - distance * 0.012, 0.28, 0.72)
	if randf() <= accuracy:
		var damage := randi_range(8, 14)
		player.call("take_damage", damage, player.global_position, -global_transform.basis.z)
	else:
		if is_instance_valid(combat_audio) and randf() < 0.55:
			var near_player := player.global_position + Vector3(randf_range(-1.5, 1.5), randf_range(0.7, 1.6), randf_range(-1.5, 1.5))
			combat_audio.call("play_bullet_whiz", near_player, 0.75)

func _set_running_pose(running: bool) -> void:
	if is_instance_valid(run_visual):
		run_visual.visible = running
	if is_instance_valid(aim_visual):
		aim_visual.visible = not running

func take_damage(amount: int, _hit_position: Vector3, _hit_direction: Vector3) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	health = 0
	velocity = Vector3.ZERO
	set_physics_process(false)
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	_set_running_pose(false)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual_root, "rotation:z", deg_to_rad(82.0), 0.38)
	tween.parallel().tween_property(visual_root, "position:y", 0.06, 0.38)
	get_tree().create_timer(5.5).timeout.connect(queue_free)
	died.emit(self)
