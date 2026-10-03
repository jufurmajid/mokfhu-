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
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.13, 0.16, 0.62)
	body.mesh = body_mesh
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("272a25")
	dark.metallic = 0.28
	dark.roughness = 0.58
	body.material_override = dark
	weapon.add_child(body)
	var stock := MeshInstance3D.new()
	var stock_mesh := BoxMesh.new()
	stock_mesh.size = Vector3(0.1, 0.12, 0.28)
	stock_mesh.material = dark
	stock.mesh = stock_mesh
	stock.position.z = 0.38
	weapon.add_child(stock)
	var magazine_mesh := MeshInstance3D.new()
	var mag := BoxMesh.new()
	mag.size = Vector3(0.1, 0.25, 0.16)
	mag.material = dark
	magazine_mesh.mesh = mag
	magazine_mesh.position = Vector3(0, -0.17, 0.05)
	magazine_mesh.rotation.x = -0.12
	weapon.add_child(magazine_mesh)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.025
	barrel_mesh.bottom_radius = 0.025
	barrel_mesh.height = 0.36
	barrel_mesh.material = dark
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI / 2
	barrel.position.z = -0.47
	weapon.add_child(barrel)

func _process(delta: float) -> void:
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	if recoil > 0.0:
		recoil = move_toward(recoil, 0.0, delta * 3.2)
		weapon.position.y = -0.27 + recoil * 0.06
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
