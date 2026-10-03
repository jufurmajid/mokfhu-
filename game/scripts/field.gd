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
	_add_box("Dry earth", Vector3(0, -0.55, 0), Vector3(90, 1, 90), Color("76694f"), true)
	_add_box("Dusty road", Vector3(0, -0.02, 0), Vector3(8, 0.08, 76), Color("9b896b"), false)
	# Original compact outpost layout: low cover, two small structures and a clear central lane.
	_add_box("West sandbag line", Vector3(-7, 0.55, 3), Vector3(1.6, 1.1, 9), Color("8a7659"), true)
	_add_box("East sandbag line", Vector3(7, 0.55, -7), Vector3(1.6, 1.1, 9), Color("8a7659"), true)
	_add_box("West outpost", Vector3(-16, 2, -9), Vector3(9, 4, 9), Color("81745e"), true)
	_add_box("East outpost", Vector3(16, 1.6, 10), Vector3(8, 3.2, 10), Color("736c58"), true)
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
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.65 + float(i % 2) * 0.18, 0.12)
		blade.mesh = mesh
		blade.position = Vector3(randf_range(-0.35, 0.35), 0.35, randf_range(-0.35, 0.35))
		blade.rotation.z = randf_range(-0.35, 0.35)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("686547")
		mat.roughness = 1.0
		blade.material_override = mat
		root.add_child(blade)

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
