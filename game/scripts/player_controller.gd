extends CharacterBody3D
signal health_changed(value: int)
signal ammo_changed(current: int, reserve: int)
signal died

const GRAVITY := 18.0
const WALK_SPEED := 5.2
const RELOAD_SECONDS := 1.45
var health := 100
var magazine := 30
var reserve_ammo := 120
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var pitch := 0.0
var shot_cooldown := 0.0
var reloading := false
var reload_timer := 0.0
var recoil := 0.0
var flash_timer := 0.0
var combat_audio: Node
var camera: Camera3D
var weapon: Node3D
var hud: CanvasLayer

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
	var pivot := Node3D.new()
	pivot.name = "View"
	pivot.position.y = 1.55
	add_child(pivot)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 78
	pivot.add_child(camera)
	_build_weapon(pivot)
	_health_signal()
	_ammo_signal()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_weapon(parent: Node3D) -> void:
	weapon = Node3D.new()
	weapon.position = Vector3(0.29, -0.27, -0.52)
	parent.add_child(weapon)
	# Sleeved arms and gloves connect the rifle to the view so it no longer floats.
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Color("555b49")
	sleeve.roughness = 0.96
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color("383a31")
	glove.roughness = 0.92
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.105
		arm_mesh.height = 0.65
		arm.mesh = arm_mesh
		arm.material_override = sleeve
		arm.position = Vector3(side * 0.22, -0.22 - (0.04 if side < 0.0 else 0.0), -0.16)
		arm.rotation = Vector3(PI / 2.0, 0.0, side * 0.28)
		weapon.add_child(arm)
		var hand := MeshInstance3D.new()
		var hand_mesh := SphereMesh.new()
		hand_mesh.radius = 0.105
		hand_mesh.height = 0.20
		hand.mesh = hand_mesh
		hand.scale = Vector3(1.0, 0.7, 1.25)
		hand.material_override = glove
		hand.position = Vector3(side * 0.12, -0.22, -0.38 if side > 0.0 else -0.22)
		weapon.add_child(hand)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("272a25")
	dark.metallic = 0.28
	dark.roughness = 0.72
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("765235")
	wood.roughness = 0.82
	_weapon_box("Receiver", Vector3(0.145, 0.17, 0.43), Vector3(0, 0, -0.02), dark)
	_weapon_box("DustCover", Vector3(0.13, 0.045, 0.37), Vector3(0, 0.105, 0.01), dark)
	_weapon_box("ReceiverFront", Vector3(0.14, 0.13, 0.12), Vector3(0, -0.005, -0.27), dark)
	_weapon_box("WoodStock", Vector3(0.125, 0.145, 0.34), Vector3(0, -0.025, 0.36), wood, Vector3(0.0, 0.0, -0.08))
	_weapon_box("StockButtPlate", Vector3(0.13, 0.17, 0.035), Vector3(0, -0.025, 0.535), dark)
	_weapon_box("PistolGrip", Vector3(0.09, 0.22, 0.12), Vector3(0, -0.18, 0.13), wood, Vector3(-0.18, 0.0, 0.12))
	_weapon_capsule("WoodHandguard", 0.083, 0.34, Vector3(0, -0.005, -0.43), wood, Vector3(PI / 2.0, 0.0, 0.0))
	# The segmented forward bend gives the magazine the distinctive curved AK profile.
	var mag_offsets := [Vector3(0, -0.14, 0.045), Vector3(0, -0.22, 0.075), Vector3(0, -0.30, 0.12), Vector3(0, -0.37, 0.17)]
	for index in mag_offsets.size():
		var segment_size := Vector3(0.102, 0.105, 0.145)
		var segment := _weapon_box("CurvedMagazine_%d" % index, segment_size, mag_offsets[index], dark)
		segment.rotation.x = -0.12 - float(index) * 0.09
	_weapon_box("MagazineBase", Vector3(0.106, 0.045, 0.13), Vector3(0, -0.425, 0.205), dark, Vector3(-0.40, 0.0, 0.0))
	_weapon_box("TriggerBlock", Vector3(0.055, 0.11, 0.10), Vector3(0, -0.105, 0.115), dark)
	_weapon_cylinder("Barrel", 0.026, 0.62, Vector3(0, 0.02, -0.72), dark)
	_weapon_cylinder("GasTube", 0.033, 0.36, Vector3(0, 0.145, -0.43), dark)
	_weapon_cylinder("MuzzleBrake", 0.037, 0.085, Vector3(0, 0.02, -1.06), dark)
	_weapon_box("FrontSightBase", Vector3(0.17, 0.045, 0.07), Vector3(0, 0.13, -0.84), dark)
	_weapon_box("FrontSightPost", Vector3(0.025, 0.12, 0.03), Vector3(0, 0.205, -0.84), dark)
	_weapon_box("RearSightBase", Vector3(0.14, 0.055, 0.075), Vector3(0, 0.13, -0.10), dark)
	_weapon_box("RearSightNotch", Vector3(0.045, 0.035, 0.04), Vector3(0, 0.175, -0.10), dark)
	_weapon_box("BoltHandle", Vector3(0.10, 0.045, 0.045), Vector3(0.105, 0.035, -0.02), dark)
	var flash := OmniLight3D.new()
	flash.name = "MuzzleFlash"
	flash.position = Vector3(0, 0.02, -1.10)
	flash.light_color = Color("ffcf84")
	flash.light_energy = 0.0
	flash.omni_range = 3.0
	flash.shadow_enabled = false
	weapon.add_child(flash)

func _weapon_box(label: String, size: Vector3, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	weapon.add_child(part)
	return part

func _weapon_cylinder(label: String, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	part.mesh = mesh
	part.rotation.x = PI / 2.0
	part.position = position
	part.material_override = material
	weapon.add_child(part)
	return part

func _weapon_capsule(label: String, radius: float, height: float, position: Vector3, material: Material, rotation: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	part.mesh = mesh
	part.rotation = rotation
	part.position = position
	part.material_override = material
	weapon.add_child(part)
	return part

func _process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	if recoil > 0.0:
		recoil = move_toward(recoil, 0.0, delta * 3.2)
		weapon.position.y = -0.27 + recoil * 0.06
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			weapon.get_node("MuzzleFlash").light_energy = 0.0
	if reloading:
		reload_timer -= delta
		weapon.rotation.x = lerpf(weapon.rotation.x, -0.6, delta * 5.0)
		if reload_timer <= 0.0:
			var needed: int = 30 - magazine
			var loaded: int = mini(needed, reserve_ammo)
			magazine += loaded
			reserve_ammo -= loaded
			reloading = false
			weapon.rotation.x = 0.0
			_ammo_signal()
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_just_pressed("fire"):
		request_fire()

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
	camera.rotation.x = pitch

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
	shot_cooldown = 0.105
	recoil = minf(1.0, recoil + 0.58)
	weapon.rotation.x = -recoil * 0.06
	weapon.get_node("MuzzleFlash").light_energy = 1.6
	flash_timer = 0.045
	_ammo_signal()
	combat_audio.call("play_player_shot", camera.global_position)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_transform.basis.z * 100.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(34, hit.position, -camera.global_transform.basis.z)

func reload() -> void:
	if reloading or magazine >= 30 or reserve_ammo <= 0:
		return
	reloading = true
	reload_timer = RELOAD_SECONDS
	combat_audio.call("play_reload", camera.global_position)

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
