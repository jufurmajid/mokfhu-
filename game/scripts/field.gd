extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const AUDIO_SCRIPT = preload("res://scripts/combat_audio.gd")
const HUD_SCRIPT = preload("res://scripts/mobile_hud.gd")

var player: CharacterBody3D
var hud: CanvasLayer
var combat_audio: Node
var enemies: Array[Node3D] = []
var remaining := 0
var status_label: Label

func _ready() -> void:
	_build_environment()
	_build_field()
	combat_audio = AUDIO_SCRIPT.new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.set("combat_audio", combat_audio)
	player.position = Vector3(0, 0.05, 12)
	add_child(player)
	hud = HUD_SCRIPT.new()
	hud.name = "MobileHUD"
	add_child(hud)
	hud.fire_requested.connect(player.request_fire)
	hud.reload_requested.connect(player.reload)
	hud.volume_changed.connect(combat_audio.set_master_volume)
	hud.move_changed.connect(player.set_touch_move)
	hud.look_delta.connect(player.add_touch_look)
	combat_audio.set_master_volume(0.85)
	player.connect("health_changed", Callable(hud, "set_health"))
	player.connect("ammo_changed", Callable(hud, "set_ammo"))
	player.connect("died", Callable(self, "_on_player_died"))
	status_label = hud.get_node("Status")
	_spawn_enemies()
	_update_status()

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("667c7b")
	sky_material.sky_horizon_color = Color("c5b99e")
	sky_material.ground_bottom_color = Color("514b3c")
	sky_material.ground_horizon_color = Color("b7a98d")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4b09c")
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ffe3b5")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

func _build_field() -> void:
	_add_ground()
	_add_box("Dusty road", Vector3(0, -0.02, 0), Vector3(8, 0.08, 76), Color("9b896b"), false)
	# Fragmented field cover and wall-built shelters leave visible entrances and firing gaps.
	_add_sandbag_line("West sandbag line", Vector3(-7, 0.34, 3), 8, true)
	_add_sandbag_line("East sandbag line", Vector3(7, 0.34, -7), 8, false)
	_build_outpost("West outpost", Vector3(-16, 0, -9), Vector2(9, 9), 3.8, Color("81745e"))
	_build_outpost("East outpost", Vector3(16, 0, 10), Vector2(8, 10), 3.2, Color("736c58"))
	_add_box("Concrete barrier A", Vector3(-3.5, 0.75, -9), Vector3(4.5, 1.5, 1), Color("8d8979"), true)
	_add_box("Concrete barrier B", Vector3(4, 0.65, 13), Vector3(4, 1.3, 1), Color("98907e"), true)
	_add_box("Supply crates", Vector3(-11, 0.7, 8), Vector3(2.2, 1.4, 2), Color("6a614b"), true)
	_add_box("Supply crates 2", Vector3(11, 0.7, -14), Vector3(2.2, 1.4, 2), Color("625b47"), true)
	_add_rock(Vector3(-23, 0.7, 5), Vector3(3.1, 1.5, 2.4))
	_add_rock(Vector3(23, 0.9, -4), Vector3(3.8, 1.8, 2.8))
	_add_rock(Vector3(18, 0.55, -23), Vector3(2.3, 1.1, 1.8))
	_add_shrub(Vector3(-20, 0, -20))
	_add_shrub(Vector3(22, 0, 17))
	_add_shrub(Vector3(-13, 0, 22))

func _add_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Dry earth"
	ground.position.y = -0.08
	add_child(ground)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(90, 90)
	plane.mesh = mesh
	var noise := FastNoiseLite.new()
	noise.seed = 6142
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var grain := noise.get_noise_2d(float(x), float(y))
			var fleck := randf_range(-0.025, 0.025)
			var value := clampf(0.48 + grain * 0.16 + fleck, 0.0, 1.0)
			image.set_pixel(x, y, Color(value * 0.88, value * 0.80, value * 0.66))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("76694f")
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(18, 18, 18)
	material.roughness = 1.0
	plane.material_override = material
	ground.add_child(plane)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(90, 0.3, 90)
	collision.shape = shape
	collision.position.y = -0.12
	ground.add_child(collision)

func _add_sandbag_line(label: String, center: Vector3, count: int, along_x: bool) -> void:
	var root := Node3D.new()
	root.name = label
	add_child(root)
	var sack_material := StandardMaterial3D.new()
	sack_material.albedo_color = Color("8a7659")
	sack_material.roughness = 1.0
	for i in count:
		var sack := StaticBody3D.new()
		var offset := (float(i) - float(count - 1) * 0.5) * 0.72
		sack.position = center + (Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset))
		root.add_child(sack)
		var mesh_node := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.29
		capsule_mesh.height = 0.82
		mesh_node.mesh = capsule_mesh
		mesh_node.rotation.z = PI / 2.0 if along_x else 0.0
		mesh_node.rotation.x = 0.0 if along_x else PI / 2.0
		mesh_node.material_override = sack_material
		sack.add_child(mesh_node)
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.28
		shape.height = 0.78
		collider.shape = shape
		collider.rotation.z = PI / 2.0 if along_x else 0.0
		collider.rotation.x = 0.0 if along_x else PI / 2.0
		sack.add_child(collider)

func _build_outpost(label: String, center: Vector3, footprint: Vector2, height: float, tint: Color) -> void:
	var x := footprint.x
	var z := footprint.y
	var t := 0.42
	var wall_y := height * 0.5
	# Front wall has a wide doorway; side walls have two firing slits.
	_add_box(label + " front left", center + Vector3(-x * 0.31, wall_y, -z * 0.5), Vector3(x * 0.38, height, t), tint, true)
	_add_box(label + " front right", center + Vector3(x * 0.31, wall_y, -z * 0.5), Vector3(x * 0.38, height, t), tint, true)
	_add_box(label + " doorway lintel", center + Vector3(0, height - 0.32, -z * 0.5), Vector3(x * 0.24, 0.64, t), tint.darkened(0.08), true)
	_add_box(label + " rear wall", center + Vector3(0, wall_y, z * 0.5), Vector3(x, height, t), tint.darkened(0.06), true)
	for side in [-1.0, 1.0]:
		_add_box(label + " side lower", center + Vector3(side * x * 0.5, 0.55, 0), Vector3(t, 1.1, z), tint.darkened(0.03), true)
		_add_box(label + " side upper", center + Vector3(side * x * 0.5, height - 0.28, 0), Vector3(t, 0.56, z), tint.darkened(0.03), true)
		_add_box(label + " side front post", center + Vector3(side * x * 0.5, (height + 1.1) * 0.5, -z * 0.40), Vector3(t, height - 1.1, z * 0.20), tint.darkened(0.03), true)
		_add_box(label + " side rear post", center + Vector3(side * x * 0.5, (height + 1.1) * 0.5, z * 0.40), Vector3(t, height - 1.1, z * 0.20), tint.darkened(0.03), true)
	_add_box(label + " sheet roof", center + Vector3(0, height + 0.08, 0), Vector3(x + 0.5, 0.18, z + 0.5), Color("514d41"), true)

func _add_box(label: String, pos: Vector3, size: Vector3, tint: Color, solid: bool) -> void:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = label
	root.position = pos
	add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)

func _add_rock(pos: Vector3, size: Vector3) -> void:
	var rock := MeshInstance3D.new()
	rock.position = pos
	rock.scale = size * 0.5
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	rock.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("716d5d")
	mat.roughness = 1.0
	rock.material_override = mat
	add_child(rock)
	var body := StaticBody3D.new()
	body.position = pos
	add_child(body)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = maxf(size.x, size.z) * 0.34
	collider.shape = shape
	body.add_child(collider)

func _add_shrub(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	for i in 4:
		var leaf := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 4
		leaf.mesh = mesh
		leaf.scale = Vector3(0.40, randf_range(0.35, 0.60), 0.38)
		leaf.position = Vector3(randf_range(-0.28, 0.28), 0.24, randf_range(-0.28, 0.28))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("686547")
		mat.roughness = 1.0
		leaf.material_override = mat
		root.add_child(leaf)

func _spawn_enemies() -> void:
	var locations := [Vector3(-16, 0, -15), Vector3(13, 0, -18), Vector3(17, 0, 1), Vector3(-2, 0, -27), Vector3(4, 0, 25)]
	for index in locations.size():
		var enemy := CharacterBody3D.new()
		enemy.name = "Raider_%02d" % (index + 1)
		enemy.set_script(ENEMY_SCRIPT)
		enemy.position = locations[index]
		enemy.set("player", player)
		enemy.set("combat_audio", combat_audio)
		enemy.connect("died", Callable(self, "_on_enemy_died"))
		add_child(enemy)
		enemies.append(enemy)
	remaining = enemies.size()

func _on_enemy_died(_enemy: Node3D) -> void:
	remaining = maxi(0, remaining - 1)
	_update_status()

func _on_player_died() -> void:
	status_label.text = "انتهت المهمة — أعد المحاولة"

func _update_status() -> void:
	if is_instance_valid(status_label):
		status_label.text = "نقطة التفتيش  •  أعداء متبقون: %d" % remaining
