extends CanvasLayer
signal fire_requested
signal reload_requested
signal volume_changed(value: float)
signal move_changed(value: Vector2)
signal look_delta(value: Vector2)

const FIRE_REPEAT := 0.105
const JOYSTICK_RADIUS := 64.0
const SAFE_MARGIN := 28.0

var health_bar: ProgressBar
var ammo_label: Label
var fire_button: Button
var reload_button: Button
var joystick_base: Panel
var joystick_knob: Panel
var root: Control
var move_origin := Vector2.ZERO
var move_touch := -1
var look_touch := -1
var fire_held := false
var fire_timer := 0.0
var volume_levels := [0.85, 0.55, 0.28, 0.0]
var volume_labels := ["الصوت 85%", "الصوت 55%", "الصوت 28%", "الصوت مغلق"]
var volume_index := 0

func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_layout_controls)
	call_deferred("_layout_controls")

func _process(delta: float) -> void:
	if fire_held:
		fire_timer -= delta
		if fire_timer <= 0.0:
			fire_requested.emit()
			fire_timer = FIRE_REPEAT

func _build_ui() -> void:
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	var shade := ColorRect.new()
	shade.name = "TopShade"
	shade.anchor_right = 1.0
	shade.offset_bottom = 96.0
	shade.color = Color(0.02, 0.025, 0.02, 0.24)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var reticle := Label.new()
	reticle.name = "Reticle"
	reticle.text = "•"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.offset_left = -18.0
	reticle.offset_top = -18.0
	reticle.offset_right = 18.0
	reticle.offset_bottom = 18.0
	reticle.add_theme_font_size_override("font_size", 30)
	reticle.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82, 0.92))
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reticle)

	var mission := Label.new()
	mission.name = "Status"
	mission.text = "منطقة العمليات"
	mission.add_theme_font_size_override("font_size", 20)
	mission.add_theme_color_override("font_color", Color("f3ead8"))
	root.add_child(mission)

	health_bar = ProgressBar.new()
	health_bar.name = "Health"
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	root.add_child(health_bar)

	ammo_label = Label.new()
	ammo_label.name = "Ammo"
	ammo_label.text = "30 / 120"
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 27)
	ammo_label.add_theme_color_override("font_color", Color("fff1cf"))
	ammo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	ammo_label.add_theme_constant_override("shadow_offset_x", 2)
	ammo_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(ammo_label)

	fire_button = _make_action_button("إطلاق", Color("a43b2d"), 22)
	fire_button.name = "FireButton"
	fire_button.button_down.connect(_start_fire)
	fire_button.button_up.connect(_stop_fire)
	root.add_child(fire_button)

	reload_button = _make_action_button("تلقيم", Color("46554a"), 17)
	reload_button.name = "ReloadButton"
	reload_button.pressed.connect(reload_requested.emit)
	root.add_child(reload_button)

	var sound_button := _make_action_button(volume_labels[volume_index], Color("303632"), 13)
	sound_button.name = "SoundButton"
	sound_button.pressed.connect(_cycle_volume.bind(sound_button))
	root.add_child(sound_button)

	joystick_base = Panel.new()
	joystick_base.name = "MovePad"
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.06, 0.08, 0.07, 0.34)
	base_style.border_color = Color(0.93, 0.88, 0.72, 0.42)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(74)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	root.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "MoveKnob"
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.94, 0.89, 0.73, 0.58)
	knob_style.set_corner_radius_all(32)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)

func _make_action_button(caption: String, tint: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint, 0.82)
	normal.border_color = Color(1, 1, 1, 0.12)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(26)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(tint.lightened(0.12), 0.96)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _layout_controls() -> void:
	if not is_instance_valid(root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var min_side := minf(viewport_size.x, viewport_size.y)
	var ui_scale := clampf(min_side / 720.0, 0.72, 1.12)
	var right_margin := SAFE_MARGIN * ui_scale
	var bottom_margin := SAFE_MARGIN * ui_scale

	var status := root.get_node("Status") as Label
	status.position = Vector2(24, 16) * ui_scale
	status.size = Vector2(minf(430.0 * ui_scale, viewport_size.x * 0.54), 34.0 * ui_scale)
	status.add_theme_font_size_override("font_size", int(19.0 * ui_scale))

	health_bar.position = Vector2(24, 54) * ui_scale
	health_bar.size = Vector2(195, 17) * ui_scale

	var sound := root.get_node("SoundButton") as Button
	sound.size = Vector2(126, 38) * ui_scale
	sound.position = Vector2(viewport_size.x - sound.size.x - right_margin, 16.0 * ui_scale)

	var fire_size := 104.0 * ui_scale
	fire_button.size = Vector2(fire_size, fire_size)
	fire_button.position = Vector2(
		viewport_size.x - fire_size - right_margin,
		viewport_size.y - fire_size - bottom_margin
	)
	fire_button.add_theme_font_size_override("font_size", int(22.0 * ui_scale))

	reload_button.size = Vector2(92, 50) * ui_scale
	reload_button.position = Vector2(
		fire_button.position.x - reload_button.size.x - 16.0 * ui_scale,
		fire_button.position.y + (fire_size - reload_button.size.y) * 0.5
	)
	reload_button.add_theme_font_size_override("font_size", int(17.0 * ui_scale))

	ammo_label.size = Vector2(190, 40) * ui_scale
	ammo_label.position = Vector2(
		viewport_size.x - ammo_label.size.x - right_margin,
		fire_button.position.y - 44.0 * ui_scale
	)
	ammo_label.add_theme_font_size_override("font_size", int(25.0 * ui_scale))

	var pad_size := 138.0 * ui_scale
	joystick_base.size = Vector2(pad_size, pad_size)
	joystick_base.position = Vector2(30.0 * ui_scale, viewport_size.y - pad_size - 30.0 * ui_scale)
	var knob_size := 58.0 * ui_scale
	joystick_knob.size = Vector2(knob_size, knob_size)
	_reset_knob()

func _input(event: InputEvent) -> void:
	var size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if _point_inside_control(event.position, fire_button) or _point_inside_control(event.position, reload_button):
				return
			if event.position.x < size.x * 0.48 and event.position.y > size.y * 0.38 and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
				_place_move_pad(event.position)
			elif event.position.x > size.x * 0.45 and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == move_touch:
				move_touch = -1
				move_changed.emit(Vector2.ZERO)
				_layout_controls()
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			var scale := maxf(joystick_base.size.x / 138.0, 0.5)
			var delta: Vector2 = (event.position - move_origin) / (JOYSTICK_RADIUS * scale)
			var clamped := delta.limit_length(1.0)
			var center := (joystick_base.size - joystick_knob.size) * 0.5
			joystick_knob.position = center + clamped * (joystick_base.size.x * 0.25)
			move_changed.emit(clamped)
		elif event.index == look_touch:
			look_delta.emit(event.relative * 0.00235)

func _point_inside_control(point: Vector2, control: Control) -> bool:
	return control.get_global_rect().has_point(point)

func _place_move_pad(point: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	var half := joystick_base.size * 0.5
	joystick_base.position = Vector2(
		clampf(point.x - half.x, 10.0, size.x * 0.48 - joystick_base.size.x),
		clampf(point.y - half.y, size.y * 0.38, size.y - joystick_base.size.y - 10.0)
	)
	_reset_knob()

func _reset_knob() -> void:
	if is_instance_valid(joystick_base) and is_instance_valid(joystick_knob):
		joystick_knob.position = (joystick_base.size - joystick_knob.size) * 0.5

func _start_fire() -> void:
	fire_held = true
	fire_timer = 0.0

func _stop_fire() -> void:
	fire_held = false

func _cycle_volume(button: Button) -> void:
	volume_index = (volume_index + 1) % volume_levels.size()
	button.text = volume_labels[volume_index]
	volume_changed.emit(volume_levels[volume_index])

func set_health(value: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.value = value
		health_bar.modulate = Color("df5a44") if value < 35 else Color.WHITE

func set_ammo(current: int, reserve: int) -> void:
	if is_instance_valid(ammo_label):
		ammo_label.text = "%02d / %03d" % [current, reserve]
