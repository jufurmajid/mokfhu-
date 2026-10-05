extends SceneTree

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(message: String) -> int:
	push_error("MOKFHU_FATAL: " + message)
	return 1

func _run() -> void:
	var scene := load("res://scenes/field.tscn") as PackedScene
	if scene == null:
		push_error("MOKFHU_FATAL: field scene missing")
		quit(1)
		return

	var field := scene.instantiate() as Node3D
	root.add_child(field)
	await process_frame

	var failures := 0

	var floor := field.get("test_floor") as MeshInstance3D
	if floor == null or floor.mesh == null:
		failures += _fail("test floor missing")
	elif not (floor.mesh is PlaneMesh):
		failures += _fail("test floor is not PlaneMesh")
	else:
		var plane := floor.mesh as PlaneMesh
		if plane.size.x < 120.0 or plane.size.y < 120.0:
			failures += _fail("test floor is not wide enough")
		if plane.material == null or not (plane.material is ShaderMaterial):
			failures += _fail("procedural sand shader is missing")

	if ResourceLoader.exists("res://scripts/enemy.gd"):
		failures += _fail("enemy.gd still exists in clean milestone")
	if ResourceLoader.exists("res://scripts/projectile.gd"):
		failures += _fail("projectile.gd still exists in clean milestone")

	var enemies := field.find_children("Enemy*", "CharacterBody3D", true, false)
	if not enemies.is_empty():
		failures += _fail("enemy nodes exist in clean milestone")

	var player := field.get("player") as CharacterBody3D
	if player == null:
		failures += _fail("player missing")
	else:
		var camera := player.get("camera") as Camera3D
		var pivot := player.get("view_pivot") as Node3D
		if camera == null or absf(camera.fov - 82.0) > 0.05 or not camera.current:
			failures += _fail("camera setup invalid")
		if pivot == null or absf(pivot.position.y - 1.55) > 0.01:
			failures += _fail("camera height invalid")

		var viewmodel := player.get("viewmodel") as Node3D
		if viewmodel == null:
			failures += _fail("AK hands viewmodel missing")
		else:
			var meshes := viewmodel.find_children("*", "MeshInstance3D", true, false)
			if meshes.is_empty():
				failures += _fail("AK hands viewmodel has no mesh")

		var anim_player := player.get("viewmodel_anim") as AnimationPlayer
		if anim_player == null:
			failures += _fail("AK AnimationPlayer missing")
		else:
			for property_name in ["anim_idle", "anim_walk", "anim_fire", "anim_reload"]:
				var anim_name := String(player.get(property_name))
				if anim_name.is_empty() or not anim_player.has_animation(StringName(anim_name)):
					failures += _fail("%s unresolved" % property_name)

		var before := int(player.get("magazine"))
		player.call("request_fire")
		if int(player.get("magazine")) != before - 1:
			failures += _fail("fire input did not consume one round")

		var shot_audio := player.get("shot_audio") as AudioStreamPlayer
		if shot_audio == null or shot_audio.stream == null:
			failures += _fail("player shot audio missing")

	var hud := field.get("hud") as CanvasLayer
	if hud == null:
		failures += _fail("mobile HUD missing")
	else:
		for control_name in ["fire_button", "reload_button", "joystick_base", "joystick_knob", "ammo_label"]:
			if hud.get(control_name) == null:
				failures += _fail("HUD control missing: %s" % control_name)

	# Stop any audio voice started by the fire validation and free the scene
	# before quitting headless Godot. This avoids false-positive resource leak
	# errors from the OGG playback object during CI shutdown.
	if player != null:
		var cleanup_shot := player.get("shot_audio") as AudioStreamPlayer
		var cleanup_reload := player.get("reload_audio") as AudioStreamPlayer
		if cleanup_shot != null:
			cleanup_shot.stop()
		if cleanup_reload != null:
			cleanup_reload.stop()
	field.queue_free()
	await process_frame
	await process_frame

	if failures == 0:
		print("--- CLEAN FPS BASE VALIDATION PASSED ---")
		quit(0)
	else:
		push_error("MOKFHU_FATAL: validation failed with %d issue(s)" % failures)
		quit(1)
