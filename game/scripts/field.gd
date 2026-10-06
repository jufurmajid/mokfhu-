extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const AUDIO_SCRIPT = preload("res://scripts/combat_audio.gd")
const HUD_SCRIPT = preload("res://scripts/mobile_hud.gd")
const SAND_SHADER = preload("res://shaders/test_sand.gdshader")

const FLOOR_SIZE := 72.0
const ARENA_HALF := 35.0
const PLAYER_SPAWN := Vector3(0.0, 0.06, 27.0)

const COVER_SAND_BAG := "res://vendor/cover/sandbag.glb"
const COVER_JERSEY := "res://vendor/cover/jersey.glb"
const COVER_BLAST := "res://vendor/cover/blast_wall.glb"
const COVER_ROCK := "res://vendor/cover/rock.glb"

const ENEMY_SPAWNS := [
	Vector3(-14.0, 0.05, -21.0),
	Vector3(14.0, 0.05, -19.0),
	Vector3(-18.0, 0.05, 2.0),
	Vector3(17.0, 0.05, 5.0)
]

# [asset path, position, yaw degrees, collision size]
const COVER_LAYOUT := [
	[COVER_SAND_BAG, Vector3(-8.5, 0.0, 16.0), -12.0, Vector3(4.1, 1.2, 2.7)],
	[COVER_SAND_BAG, Vector3(10.5, 0.0, 11.5), 18.0, Vector3(4.1, 1.2, 2.7)],
	[COVER_SAND_BAG, Vector3(-14.0, 0.0, -4.0), 80.0, Vector3(4.1, 1.2, 2.7)],
	[COVER_SAND_BAG, Vector3(13.5, 0.0, -10.0), -72.0, Vector3(4.1, 1.2, 2.7)],

	[COVER_JERSEY, Vector3(-2.5, 0.0, 9.0), 90.0, Vector3(2.45, 0.9, 0.68)],
	[COVER_JERSEY, Vector3(2.5, 0.0, 7.5), 90.0, Vector3(2.45, 0.9, 0.68)],
	[COVER_JERSEY, Vector3(-6.0, 0.0, -8.0), 5.0, Vector3(2.45, 0.9, 0.68)],
	[COVER_JERSEY, Vector3(6.5, 0.0, -5.0), -12.0, Vector3(2.45, 0.9, 0.68)],

	[COVER_BLAST, Vector3(-24.0, 0.0, 7.0), 90.0, Vector3(4.0, 3.2, 0.72)],
	[COVER_BLAST, Vector3(23.0, 0.0, -3.0), 90.0, Vector3(4.0, 3.2, 0.72)],
	[COVER_BLAST, Vector3(0.0, 0.0, -24.0), 0.0, Vector3(4.0, 3.2, 0.72)],

	[COVER_ROCK, Vector3(-25.0, 0.0, -17.0), 28.0, Vector3(2.75, 2.2, 2.65)],
	[COVER_ROCK, Vector3(24.0, 0.0, 19.0), -34.0, Vector3(2.75, 2.2, 2.65)],
	[COVER_ROCK, Vector3(-4.5, 0.0, -16.0), 66.0, Vector3(2.75, 2.2, 2.65)],
	[COVER_ROCK, Vector3(7.0, 0.0, 20.0), -48.0, Vector3(2.75, 2.2, 2.65)]
]

var player: CharacterBody3D
var hud: CanvasLayer
var combat_audio: Node
var enemies: Array[Node3D] = []
var remaining := 0
var test_floor: MeshInstance3D
var cover_root: Node3D

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_build_environment()
	_build_floor()
	_build_cover()
	_build_gameplay()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "DesertEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("5d8eaa")
	sky_material.sky_horizon_color = Color("d7c8b1")
	sky_material.ground_bottom_color = Color("70543a")
	sky_material.ground_horizon_color = Color("b99b72")
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.78
	environment.ambient_light_energy = 0.62
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("d8c8ae")
	environment.fog_light_energy = 0.25
	environment.fog_density = 0.0014
	environment.fog_sky_affect = 0.08
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "DesertSun"
	sun.rotation_degrees = Vector3(-51.0, -34.0, 0.0)
	sun.light_color = Color("ffe3bb")
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 34.0
	sun.directional_shadow_fade_start = 0.72
	add_child(sun)

func _build_floor() -> void:
	test_floor = MeshInstance3D.new()
	test_floor.name = "DesertGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	var sand_material := ShaderMaterial.new()
	sand_material.shader = SAND_SHADER
	plane.material = sand_material
	test_floor.mesh = plane
	add_child(test_floor)

	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	body.collision_mask = 3
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(FLOOR_SIZE, 0.18, FLOOR_SIZE)
	collision.shape = shape
	collision.position.y = -0.11
	body.add_child(collision)
	add_child(body)

	_add_boundary(Vector3(0.0, 1.5, -ARENA_HALF), Vector3(FLOOR_SIZE, 3.0, 0.5))
	_add_boundary(Vector3(0.0, 1.5, ARENA_HALF), Vector3(FLOOR_SIZE, 3.0, 0.5))
	_add_boundary(Vector3(-ARENA_HALF, 1.5, 0.0), Vector3(0.5, 3.0, FLOOR_SIZE))
	_add_boundary(Vector3(ARENA_HALF, 1.5, 0.0), Vector3(0.5, 3.0, FLOOR_SIZE))

func _build_cover() -> void:
	cover_root = Node3D.new()
	cover_root.name = "RealisticCover"
	add_child(cover_root)

	var cache: Dictionary = {}
	for path in [COVER_SAND_BAG, COVER_JERSEY, COVER_BLAST, COVER_ROCK]:
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("MOKFHU_FATAL: cover asset missing: %s" % path)
			return
		cache[path] = packed

	var index := 0
	for entry in COVER_LAYOUT:
		var path: String = entry[0]
		var scene: PackedScene = cache[path]
		var visual := scene.instantiate() as Node3D
		if visual == null:
			push_error("MOKFHU_FATAL: cover asset failed to instantiate: %s" % path)
			continue
		visual.name = "CoverVisual_%02d" % index
		visual.position = entry[1]
		visual.rotation_degrees.y = entry[2]
		cover_root.add_child(visual)
		_add_cover_collision(entry[1], entry[2], entry[3], index)
		index += 1

func _add_cover_collision(position_value: Vector3, yaw_degrees: float, size_value: Vector3, index: int) -> void:
	var body := StaticBody3D.new()
	body.name = "CoverCollision_%02d" % index
	body.collision_layer = 1
	body.collision_mask = 3
	body.position = position_value
	body.rotation_degrees.y = yaw_degrees

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	collision.position.y = size_value.y * 0.5
	body.add_child(collision)
	add_child(body)

func _add_boundary(position_value: Vector3, size_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "InvisibleBoundary"
	body.collision_layer = 1
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _build_gameplay() -> void:
	combat_audio = AUDIO_SCRIPT.new()
	combat_audio.name = "CombatAudio"
	add_child(combat_audio)

	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.set("combat_audio", combat_audio)
	player.position = PLAYER_SPAWN
	add_child(player)

	hud = HUD_SCRIPT.new()
	hud.name = "MobileHUD"
	add_child(hud)

	hud.move_changed.connect(player.set_touch_move)
	hud.look_delta.connect(player.add_touch_look)
	hud.fire_requested.connect(player.request_fire)
	hud.reload_requested.connect(player.reload)
	hud.jump_requested.connect(player.request_jump)
	hud.crouch_requested.connect(player.toggle_crouch)
	hud.aim_changed.connect(player.set_aiming)
	hud.restart_requested.connect(restart_game)

	player.health_changed.connect(hud.set_health)
	player.ammo_changed.connect(hud.set_ammo)
	player.hit_confirmed.connect(hud.show_hitmarker)
	player.died.connect(_on_player_died)

	_spawn_enemies()
	player.emit_status()
	_update_enemy_count()

func _spawn_enemies() -> void:
	enemies.clear()
	for index in range(ENEMY_SPAWNS.size()):
		var enemy := CharacterBody3D.new()
		enemy.name = "Enemy_%02d" % (index + 1)
		enemy.set_script(ENEMY_SCRIPT)
		enemy.set("player", player)
		enemy.set("combat_audio", combat_audio)
		enemy.position = ENEMY_SPAWNS[index]
		enemy.connect("died", Callable(self, "_on_enemy_died"))
		add_child(enemy)
		enemies.append(enemy)
	remaining = enemies.size()

func _on_enemy_died(_enemy: Node3D) -> void:
	remaining = maxi(0, remaining - 1)
	_update_enemy_count()
	if remaining == 0:
		hud.show_mission_result("تم تأمين المنطقة", true)

func _on_player_died() -> void:
	if is_instance_valid(hud):
		hud.show_mission_result("انتهت المهمة", false)

func _update_enemy_count() -> void:
	if is_instance_valid(hud):
		hud.set_enemy_count(remaining)

func restart_game() -> void:
	get_tree().reload_current_scene()
