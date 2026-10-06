extends SceneTree

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(message: String) -> int:
	push_error("MOKFHU_FATAL: " + message)
	return 1

func _inside_viewport(control: Control, viewport_size: Vector2) -> bool:
	if control == null:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0

func _run() -> void:
	var scene := load("res://scenes/field.tscn") as PackedScene
	if scene == null:
		push_error("MOKFHU_FATAL: field scene missing")
		quit(1)
		return

	var field := scene.instantiate() as Node3D
	root.add_child(field)
	await process_frame
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
		if camera == null or absf(camera.fov - 78.0) > 0.05 or not camera.current:
			failures += _fail("camera must start at 78 degree FOV")
		if pivot == null or absf(pivot.position.y - 1.55) > 0.02:
			failures += _fail("camera height invalid")

		var mount := player.get("viewmodel_mount") as Node3D
		if mount == null:
			failures += _fail("viewmodel mount missing")

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

		var initial_position := player.get("tuned_hip_position") as Vector3
		var initial_scale := float(player.get("tuned_scale"))
		var initial_fov := float(player.get("tuned_fov"))

		player.call("adjust_viewmodel_axis", "z", 0.01)
		var changed_position := player.get("tuned_hip_position") as Vector3
		if absf(changed_position.z - (initial_position.z + 0.01)) > 0.001:
			failures += _fail("Z tuning control did not update the viewmodel position")

		player.call("adjust_viewmodel_scale", 0.005)
		if absf(float(player.get("tuned_scale")) - (initial_scale + 0.005)) > 0.001:
			failures += _fail("viewmodel scale tuning did not update")

		player.call("adjust_camera_fov", 1.0)
		if absf(float(player.get("tuned_fov")) - (initial_fov + 1.0)) > 0.01:
			failures += _fail("camera FOV tuning did not update")

		player.call("reset_viewmodel_tuning")
		var reset_position := player.get("tuned_hip_position") as Vector3
		if reset_position.distance_to(initial_position) > 0.001:
			failures += _fail("viewmodel tuner reset did not restore default position")
		if absf(float(player.get("tuned_scale")) - initial_scale) > 0.001:
			failures += _fail("viewmodel tuner reset did not restore default scale")
		if absf(float(player.get("tuned_fov")) - initial_fov) > 0.01:
			failures += _fail("viewmodel tuner reset did not restore default FOV")

		var shot_audio := player.get("shot_audio") as AudioStreamPlayer
		if shot_audio == null or shot_audio.stream == null:
			failures += _fail("player shot audio missing")

	var hud := field.get("hud") as CanvasLayer
	if hud == null:
		failures += _fail("mobile HUD missing")
	else:
		var required_controls := [
			"fire_button",
			"reload_button",
			"aim_button",
			"crouch_button",
			"jump_button",
			"joystick_base",
			"joystick_knob",
			"weapon_panel",
			"ammo_label",
			"tuning_toggle_button",
			"tuning_panel",
			"tuning_value_label",
			"tuning_copy_button"
		]
		for control_name in required_controls:
			if hud.get(control_name) == null:
				failures += _fail("HUD control missing: %s" % control_name)

		var viewport_size := root.get_visible_rect().size
		for control_name in ["fire_button", "reload_button", "aim_button", "crouch_button", "jump_button", "joystick_base", "weapon_panel", "tuning_toggle_button", "tuning_panel"]:
			var control := hud.get(control_name) as Control
			if not _inside_viewport(control, viewport_size):
				failures += _fail("HUD control is outside 1280x720 safe area: %s" % control_name)

		var tuning_panel := hud.get("tuning_panel") as Control
		if tuning_panel == null or not tuning_panel.visible:
			failures += _fail("viewmodel tuning panel must be visible by default")

		if player != null:
			hud.call("set_tuning_values",
				player.get("tuned_hip_position"),
				player.get("tuned_scale"),
				player.get("tuned_fov")
			)
			var values_label := hud.get("tuning_value_label") as Label
			if values_label == null or not values_label.text.contains("X"):
				failures += _fail("live tuning coordinate display is not updating")

	field.queue_free()
	await process_frame
	await process_frame

	if failures == 0:
		print("--- VIEWMODEL TUNER VALIDATION PASSED ---")
		quit(0)
	else:
		push_error("MOKFHU_FATAL: validation failed with %d issue(s)" % failures)
		quit(1)
