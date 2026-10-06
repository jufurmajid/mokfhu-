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
		elif mount.position.x <= 0.0 or mount.position.y >= 0.0:
			failures += _fail("AK viewmodel is not framed in lower-right first-person position")

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

		player.call("set_aiming", true)
		if not bool(player.get("aiming")):
			failures += _fail("ADS toggle did not enable aiming")
		player.call("set_aiming", false)

		var before_tune: Vector3 = player.get("tuned_hip_position")
		player.call("set_tuning_mode", true)
		player.call("adjust_viewmodel_axis", "z", 0.02)
		var after_tune: Vector3 = player.get("tuned_hip_position")
		if absf((after_tune.z - before_tune.z) - 0.02) > 0.001:
			failures += _fail("viewmodel Z tuning did not apply")
		player.call("adjust_viewmodel_scale", 0.005)
		if float(player.get("tuned_scale")) <= 0.155:
			failures += _fail("viewmodel scale tuning did not apply")
		player.call("adjust_camera_fov", 1.0)
		if float(player.get("tuned_fov")) <= 78.0:
			failures += _fail("camera FOV tuning did not apply")
		player.call("reset_viewmodel_tuning")
		player.call("set_tuning_mode", false)

		player.call("toggle_crouch")
		if not bool(player.get("crouched")):
			failures += _fail("crouch toggle did not enable crouch")
		player.call("toggle_crouch")

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
			"tuning_label"
		]
		for control_name in required_controls:
			if hud.get(control_name) == null:
				failures += _fail("HUD control missing: %s" % control_name)

		var viewport_size := root.get_visible_rect().size
		for control_name in ["fire_button", "reload_button", "aim_button", "crouch_button", "jump_button", "joystick_base", "weapon_panel", "tuning_toggle_button"]:
			var control := hud.get(control_name) as Control
			if not _inside_viewport(control, viewport_size):
				failures += _fail("HUD control is outside 1280x720 safe area: %s" % control_name)

		var fire_button := hud.get("fire_button") as Button
		var joystick := hud.get("joystick_base") as Control
		if fire_button != null and fire_button.get_global_rect().get_center().x < viewport_size.x * 0.60:
			failures += _fail("fire button is not on the right side")
		if joystick != null and joystick.get_global_rect().get_center().x > viewport_size.x * 0.35:
			failures += _fail("movement joystick is not on the left side")

		var tune_buttons: Array = hud.get("tuning_buttons")
		if tune_buttons.size() < 11:
			failures += _fail("camera tuning panel does not have all adjustment buttons")
		var tune_label := hud.get("tuning_label") as Label
		if tune_label == null or not tune_label.text.contains("X:") or not tune_label.text.contains("Z:"):
			failures += _fail("camera tuning coordinates are not visible")

	field.queue_free()
	await process_frame
	await process_frame

	if failures == 0:
		print("--- REFERENCE FPS CAMERA AND HUD VALIDATION PASSED ---")
		quit(0)
	else:
		push_error("MOKFHU_FATAL: validation failed with %d issue(s)" % failures)
		quit(1)
