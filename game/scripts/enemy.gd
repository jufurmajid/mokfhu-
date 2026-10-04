extends CharacterBody3D
signal died(enemy: Node3D)

const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
var player: Node3D
var combat_audio: Node
var health := 100
var shoot_timer := randf_range(1.0, 2.8)
var move_phase := randf() * TAU
var is_dead := false
var body_mesh: MeshInstance3D
var visual_root: Node3D
var body_collision: CollisionShape3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var muzzle_flash: OmniLight3D
var walk_cycle := randf() * TAU
var fire_kick := 0.0
var flash_timer := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	body_collision = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.75
	body_collision.shape = shape
	body_collision.position.y = 0.9
	add_child(body_collision)
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	_build_soldier()

func _build_soldier() -> void:
	var uniform := Color("555d4a") if randi() % 2 == 0 else Color("81735b")
	# Rounded low-poly silhouette reads as a person at phone scale instead of a stack of boxes.
	body_mesh = _capsule_part("Torso", 0.27, 0.76, Vector3(0, 1.12, 0), uniform)
	var vest := _capsule_part("PlateCarrier", 0.285, 0.58, Vector3(0, 1.14, -0.055), uniform.darkened(0.12))
	vest.scale = Vector3(1.0, 0.92, 0.82)
	_part("Helmet", Vector3(0.37, 0.19, 0.34), Vector3(0, 1.78, 0), Color("454c40"), true)
	_part("HelmetRim", Vector3(0.44, 0.045, 0.36), Vector3(0, 1.72, -0.025), Color("343a32"), false)
	_capsule_part("Face", 0.15, 0.27, Vector3(0, 1.55, -0.018), Color("947d62"))
	_capsule_part("Pack", 0.17, 0.50, Vector3(0, 1.18, 0.22), Color("484e40"))
	left_leg = _capsule_part("LeftLeg", 0.105, 0.62, Vector3(-0.15, 0.46, 0), uniform.darkened(0.16))
	right_leg = _capsule_part("RightLeg", 0.105, 0.62, Vector3(0.15, 0.46, 0), uniform.darkened(0.16))
	left_arm = _capsule_part("LeftArm", 0.095, 0.62, Vector3(-0.34, 1.09, -0.10), uniform)
	left_arm.rotation.z = -0.38
	right_arm = _capsule_part("RightArm", 0.095, 0.62, Vector3(0.34, 1.09, -0.17), uniform)
	right_arm.rotation.z = 0.38
	# Two pouches and an AK-like weapon profile break up the silhouette without adding heavy assets.
	_part("PouchL", Vector3(0.12, 0.16, 0.11), Vector3(-0.13, 0.98, -0.19), Color("5a503b"), true)
	_part("PouchR", Vector3(0.12, 0.16, 0.11), Vector3(0.13, 0.98, -0.19), Color("5a503b"), true)
	_part("RifleReceiver", Vector3(0.10, 0.12, 0.36), Vector3(0.28, 1.12, -0.31), Color("242722"), true)
	_capsule_part("RifleBarrel", 0.025, 0.50, Vector3(0.28, 1.13, -0.69), Color("20231f"))
	_part("RifleStock", Vector3(0.09, 0.11, 0.26), Vector3(0.28, 1.12, 0.01), Color("684b32"), true)
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.position = Vector3(0.28, 1.13, -0.96)
	muzzle_flash.light_color = Color("ffbd72")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 2.3
	muzzle_flash.shadow_enabled = false
	visual_root.add_child(muzzle_flash)

func _part(label: String, size: Vector3, pos: Vector3, tint: Color, rounded: bool = false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	if rounded:
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		part.mesh = mesh
		part.scale = size
	else:
		var mesh := BoxMesh.new()
		mesh.size = size
		part.mesh = mesh
	part.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.92
	part.material_override = material
	visual_root.add_child(part)
	return part

func _capsule_part(label: String, radius: float, height: float, pos: Vector3, tint: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	part.mesh = mesh
	part.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.94
	part.material_override = material
	visual_root.add_child(part)
	return part

func _process(delta: float) -> void:
	if is_dead:
		return
	fire_kick = move_toward(fire_kick, 0.0, delta * 7.0)
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0 and is_instance_valid(muzzle_flash):
			muzzle_flash.light_energy = 0.0
	_animate_soldier(delta)

func _animate_soldier(delta: float) -> void:
	if not is_instance_valid(visual_root):
		return
	var move_speed := Vector2(velocity.x, velocity.z).length()
	var move_strength := clampf(move_speed / 2.3, 0.0, 1.0)
	if move_strength > 0.05:
		walk_cycle += delta * 7.4
	var swing := sin(walk_cycle) * 0.52 * move_strength
	if is_instance_valid(left_leg):
		left_leg.rotation.x = swing
	if is_instance_valid(right_leg):
		right_leg.rotation.x = -swing
	if is_instance_valid(left_arm):
		left_arm.rotation.x = -swing * 0.20 - fire_kick * 0.10
	if is_instance_valid(right_arm):
		right_arm.rotation.x = swing * 0.14 - fire_kick * 0.18
	visual_root.position.y = abs(sin(walk_cycle * 2.0)) * 0.035 * move_strength
	visual_root.rotation.x = -fire_kick * 0.045
	visual_root.rotation.z = sin(walk_cycle) * 0.018 * move_strength

func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(player) or int(player.get("health")) <= 0:
		return
	shoot_timer -= delta
	var to_player: Vector3 = player.global_position - global_position
	var distance := to_player.length()
	var flat := Vector3(to_player.x, 0, to_player.z).normalized()
	if distance > 11.0:
		velocity.x = flat.x * 2.3
		velocity.z = flat.z * 2.3
	else:
		move_phase += delta * 0.6
		var strafe := Vector3(-flat.z, 0, flat.x) * sin(move_phase) * 0.75
		velocity.x = strafe.x
		velocity.z = strafe.z
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
	velocity.y = -0.15
	move_and_slide()
	if shoot_timer <= 0.0 and distance < 48.0:
		_fire_at_player()
		shoot_timer = randf_range(1.4, 2.6)

func _fire_at_player() -> void:
	var muzzle := global_position + Vector3(0, 1.28, 0) - global_transform.basis.z * 0.55
	combat_audio.call("play_enemy_shot", muzzle, player.global_position)
	fire_kick = 1.0
	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = randf_range(0.9, 1.35)
	flash_timer = 0.05
	var projectile := Node3D.new()
	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.position = muzzle
	projectile.target = player.global_position + Vector3(0, 1.1, 0)
	projectile.player = player
	projectile.combat_audio = combat_audio
	get_tree().current_scene.add_child(projectile)

func take_damage(amount: int, hit_position: Vector3, hit_direction: Vector3) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		_die(hit_position, hit_direction)

func _die(hit_position: Vector3, hit_direction: Vector3) -> void:
	is_dead = true
	set_physics_process(false)
	if is_instance_valid(visual_root):
		visual_root.visible = false
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)
	var ragdoll := RigidBody3D.new()
	ragdoll.name = "Ragdoll"
	ragdoll.position = Vector3(0, 1.0, 0)
	ragdoll.mass = 38.0
	ragdoll.linear_damp = 2.8
	ragdoll.angular_damp = 3.5
	ragdoll.collision_layer = 4
	ragdoll.collision_mask = 1
	add_child(ragdoll)
	var rag_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 0.9
	rag_shape.shape = capsule
	ragdoll.add_child(rag_shape)
	var torso := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.27
	mesh.height = 0.9
	torso.mesh = mesh
	if body_mesh.material_override:
		torso.material_override = body_mesh.material_override
	ragdoll.add_child(torso)
	var parts: Array[RigidBody3D] = [ragdoll]
	var part_specs := [
		{"name": "Head", "offset": Vector3(0, 0.53, 0), "radius": 0.16, "height": 0.3, "color": Color("454c40")},
		{"name": "LeftArm", "offset": Vector3(-0.34, 0.05, 0), "radius": 0.095, "height": 0.62, "color": Color("555d4a")},
		{"name": "RightArm", "offset": Vector3(0.34, 0.05, 0), "radius": 0.095, "height": 0.62, "color": Color("555d4a")},
		{"name": "LeftLeg", "offset": Vector3(-0.14, -0.59, 0), "radius": 0.11, "height": 0.72, "color": Color("454b3e")},
		{"name": "RightLeg", "offset": Vector3(0.14, -0.59, 0), "radius": 0.11, "height": 0.72, "color": Color("454b3e")}
	]
	for spec in part_specs:
		var limb := RigidBody3D.new()
		limb.name = spec.name
		limb.position = ragdoll.position + spec.offset
		if spec.name.contains("Arm"):
			limb.rotation.z = -0.32 if spec.name == "LeftArm" else 0.32
		limb.mass = 5.0 if spec.name.contains("Leg") else 2.2
		limb.linear_damp = 3.4
		limb.angular_damp = 4.2
		limb.collision_layer = 4
		limb.collision_mask = 1
		var limb_shape := CollisionShape3D.new()
		var limb_capsule := CapsuleShape3D.new()
		limb_capsule.radius = spec.radius
		limb_capsule.height = spec.height
		limb_shape.shape = limb_capsule
		limb.add_child(limb_shape)
		var limb_mesh := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = spec.radius
		capsule_mesh.height = spec.height
		limb_mesh.mesh = capsule_mesh
		var limb_material := StandardMaterial3D.new()
		limb_material.albedo_color = spec.color
		limb_mesh.material_override = limb_material
		limb.add_child(limb_mesh)
		add_child(limb)
		parts.append(limb)
	# Light pin joints keep the ragdoll compact and believable without a full character skeleton.
	for index in range(1, parts.size()):
		var joint := PinJoint3D.new()
		joint.position = (parts[0].position + parts[index].position) * 0.5
		add_child(joint)
		joint.node_a = joint.get_path_to(parts[0])
		joint.node_b = joint.get_path_to(parts[index])
	ragdoll.apply_impulse(hit_direction.normalized() * 1.4 + Vector3.UP * 0.45, hit_position - ragdoll.global_position)
	var cleanup := get_tree().create_timer(7.0)
	cleanup.timeout.connect(queue_free)
	died.emit(self)
