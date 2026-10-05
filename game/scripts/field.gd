extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player_controller.gd")
const HUD_SCRIPT = preload("res://scripts/mobile_hud.gd")
const SAND_SHADER = preload("res://shaders/test_sand.gdshader")

const FLOOR_SIZE := 140.0
const PLAYER_SPAWN := Vector3(0.0, 0.08, 9.0)

var player: CharacterBody3D
var hud: CanvasLayer
var test_floor: MeshInstance3D

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	_build_environment()
	_build_test_floor()
	_build_player_and_controls()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4d7fa7")
	sky_material.sky_horizon_color = Color("d7bb91")
	sky_material.ground_bottom_color = Color("5c3d24")
	sky_material.ground_horizon_color = Color("c28f54")
	sky_material.sun_angle_max = 12.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.82
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("d7c2a0")
	environment.fog_light_energy = 0.42
	environment.fog_density = 0.0017
	environment.fog_sky_affect = 0.10
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color("ffe2b2")
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	sun.directional_shadow_fade_start = 0.75
	add_child(sun)

func _build_test_floor() -> void:
	test_floor = MeshInstance3D.new()
	test_floor.name = "TestFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	var sand_material := ShaderMaterial.new()
	sand_material.shader = SAND_SHADER
	plane.material = sand_material
	test_floor.mesh = plane
	add_child(test_floor)

	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCollision"
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(FLOOR_SIZE, 0.18, FLOOR_SIZE)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.10
	floor_body.add_child(floor_collision)
	add_child(floor_body)

	_add_boundary(Vector3(0.0, 1.5, -FLOOR_SIZE * 0.5), Vector3(FLOOR_SIZE, 3.0, 0.4))
	_add_boundary(Vector3(0.0, 1.5, FLOOR_SIZE * 0.5), Vector3(FLOOR_SIZE, 3.0, 0.4))
	_add_boundary(Vector3(-FLOOR_SIZE * 0.5, 1.5, 0.0), Vector3(0.4, 3.0, FLOOR_SIZE))
	_add_boundary(Vector3(FLOOR_SIZE * 0.5, 1.5, 0.0), Vector3(0.4, 3.0, FLOOR_SIZE))

func _add_boundary(position_value: Vector3, size_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "InvisibleBoundary"
	body.position = position_value
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _build_player_and_controls() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = PLAYER_SPAWN
	add_child(player)

	hud = HUD_SCRIPT.new()
	hud.name = "MobileHUD"
	add_child(hud)
	hud.move_changed.connect(player.set_touch_move)
	hud.look_delta.connect(player.add_touch_look)
	hud.fire_requested.connect(player.request_fire)
	hud.reload_requested.connect(player.reload)
	player.ammo_changed.connect(hud.set_ammo)
	player.emit_ammo()
