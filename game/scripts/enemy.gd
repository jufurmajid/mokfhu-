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

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var hitbox := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.75
	hitbox.shape = shape
	hitbox.position.y = 0.9
	add_child(hitbox)
	_build_soldier()

func _build_soldier() -> void:
	var uniform := Color("555d4a") if randi() % 2 == 0 else Color("81735b")
	body_mesh = _part("Torso", Vector3(0.48, 0.65, 0.3), Vector3(0, 1.12, 0), uniform)
	_part("Helmet", Vector3(0.4, 0.23, 0.35), Vector3(0, 1.78, 0), Color("454c40"))
	_part("Face", Vector3(0.28, 0.26, 0.25), Vector3(0, 1.56, -0.01), Color("947d62"))
	_part("Pack", Vector3(0.36, 0.46, 0.2), Vector3(0, 1.2, 0.23), Color("484e40"))
	_part("LeftLeg", Vector3(0.19, 0.58, 0.22), Vector3(-0.14, 0.42, 0), uniform.darkened(0.16))
	_part("RightLeg", Vector3(0.19, 0.58, 0.22), Vector3(0.14, 0.42, 0), uniform.darkened(0.16))
	_part("Rifle", Vector3(0.12, 0.1, 0.68), Vector3(0.28, 1.12, -0.32), Color("242722"))

func _part(label: String, size: Vector3, pos: Vector3, tint: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.92
	part.material_override = material
	add_child(part)
	return part

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
	body_mesh.visible = false
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
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.48, 0.65, 0.3)
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
	for node in get_children():
		if node is MeshInstance3D and node != body_mesh:
			node.visible = false
		if node is CollisionShape3D and node != rag_shape:
			node.disabled = true
	var cleanup := get_tree().create_timer(7.0)
	cleanup.timeout.connect(queue_free)
	died.emit(self)
