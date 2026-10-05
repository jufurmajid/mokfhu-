extends CharacterBody3D
signal died(enemy: Node3D)

const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const ENEMY_AIM_MODEL_PATH := "res://vendor/enemy/assault_aim.glb"
const ENEMY_RUN_MODEL_PATH := "res://vendor/enemy/assault_run.glb"
const MOVE_SPEED := 2.25
const SOLDIER_HEIGHT := 1.78

var player: Node3D
var combat_audio: Node
var health := 100
var shoot_timer := randf_range(1.0, 2.2)
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
	collision_layer = 1
	collision_mask = 1
	body_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.82
	body_collision.shape = shape
	body_collision.position.y = 0.91
	add_child(body_collision)

	visual_root = Node3D.new()
	visual_root.name = "RealisticTacticalEnemy"
	add_child(visual_root)
	_build_soldier_visual()

func _build_soldier_visual() -> void:
	var aim_packed := load(ENEMY_AIM_MODEL_PATH) as PackedScene
	var run_packed := load(ENEMY_RUN_MODEL_PATH) as PackedScene
	if aim_packed == null or run_packed == null:
		push_error("MOKFHU_FATAL: ready-made realistic enemy pose models are missing")
		return

	aim_visual = aim_packed.instantiate() as Node3D
	run_visual = run_packed.instantiate() as Node3D
	if aim_visual == null or run_visual == null:
		push_error("MOKFHU_FATAL: realistic enemy pose models could not be instantiated")
		return

	for model in [aim_visual, run_visual]:
		model.rotation.y = PI
		visual_root.add_child(model)
		_normalize_soldier(model)

	aim_visual.name = "AssaultTrooperAim"
	run_visual.name = "AssaultTrooperRun"
	_set_running_pose(false)

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.position = Vector3(0.08, 1.34, -0.72)
	muzzle_flash.light_color = Color("ffb762")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 2.2
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
		var curr: Node = mesh_instance
		while curr != null and curr != root:
			if curr is Node3D:
				relative = (curr as Node3D).transform * relative
			curr = curr.get_parent()
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

func _normalize_soldier(model: Node3D) -> void:
	var bounds := _model_bounds(model)
	if bounds.size.y <= 0.001:
		push_error("MOKFHU_FATAL: enemy GLB contains no visible human mesh")
		return
	var scale_factor := SOLDIER_HEIGHT / bounds.size.y
	model.scale = Vector3.ONE * scale_factor
	var center_x := bounds.position.x + bounds.size.x * 0.5
	var center_z := bounds.position.z + bounds.size.z * 0.5
	model.position.x = -center_x * scale_factor
	model.position.y = -bounds.position.y * scale_factor
	model.position.z = -center_z * scale_factor

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and is_instance_valid(muzzle_flash):
			muzzle_flash.light_energy = 0.0

	if pose_lock_timer > 0.0:
		pose_lock_timer -= delta
	elif not is_dead:
		var speed := Vector2(velocity.x, velocity.z).length()
		_set_running_pose(speed > 0.25)

func _set_running_pose(running: bool) -> void:
	if is_instance_valid(run_visual):
		run_visual.visible = running
	if is_instance_valid(aim_visual):
		aim_visual.visible = not running

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or int(player.get("health")) <= 0:
		return

	shoot_timer -= delta
	var to_player: Vector3 = player.global_position - global_position
	var distance := to_player.length()
	var flat := Vector3(to_player.x, 0.0, to_player.z).normalized()

	if distance > 10.5:
		velocity.x = flat.x * MOVE_SPEED
		velocity.z = flat.z * MOVE_SPEED
	else:
		move_phase += delta * 0.85
		var strafe := Vector3(-flat.z, 0.0, flat.x) * sin(move_phase) * 0.72
		velocity.x = strafe.x
		velocity.z = strafe.z

	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.15
	move_and_slide()

	if shoot_timer <= 0.0 and distance < 38.0:
		_fire_at_player()
		shoot_timer = randf_range(1.45, 2.35)

func _fire_at_player() -> void:
	pose_lock_timer = 0.42
	_set_running_pose(false)
	var muzzle := global_position + Vector3(0.0, 1.34, 0.0) - global_transform.basis.z * 0.72
	if is_instance_valid(combat_audio):
		combat_audio.call("play_enemy_shot", muzzle, player.global_position)
	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = randf_range(0.9, 1.35)
	flash_timer = 0.05

	var projectile := Node3D.new()
	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.position = muzzle
	projectile.target = player.global_position + Vector3(0, 1.08, 0)
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
	set_process(false)
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	_set_running_pose(false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual_root, "rotation:z", deg_to_rad(84.0), 0.46)
	tween.parallel().tween_property(visual_root, "position:y", 0.10, 0.46)
	var cleanup := get_tree().create_timer(6.0)
	cleanup.timeout.connect(queue_free)
	died.emit(self)
