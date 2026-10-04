extends CanvasLayer
signal fire_requested
signal reload_requested
signal volume_changed(value: float)
signal move_changed(value: Vector2)
signal look_delta(value: Vector2)

var health_bar: ProgressBar
var ammo_label: Label
var fire_button: Button
var reload_button: Button
var move_origin := Vector2.ZERO
var move_touch := -1
var look_touch := -1
var fire_held := false
var fire_timer := 0.0
var volume_levels := [0.85, 0.55, 0.28, 0.0]
var volume_labels := ["الصوت 85%", "الصوت 55%", "الصوت 28%", "الصوت مغلق"]
var volume_index := 0
var joystick_base: Panel
var joystick_knob: Panel

func _ready() -> void:
	_build_ui()

func _process(delta: float) -> void:
	if fire_held:
		fire_timer -= delta
		if fire_timer <= 0.0:
			fire_requested.emit()
			fire_timer = 0.11

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	var reticle := Label.new()
	reticle.text = "+"
	reticle.add_theme_font_size_override("font_size", 28)
	reticle.add_theme_color_override("font_color", Color(0.93, 0.91, 0.81, 0.88))
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-8, -18)
	root.add_child(reticle)
	var mission := Label.new()
	mission.name = "Status"
	mission.text = "نقطة التفتيش"
	mission.position = Vector2(24, 18)
	mission.add_theme_font_size_override("font_size", 19)
	mission.add_theme_color_override("font_color", Color("eee9d8"))
	root.add_child(mission)
	var sound_button := Button.new()
	sound_button.text = volume_labels[volume_index]
	sound_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sound_button.position = Vector2(-160, 18)
	sound_button.size = Vector2(142, 42)
	sound_button.add_theme_font_size_override("font_size", 14)
	sound_button.pressed.connect(_cycle_volume.bind(sound_button))
	root.add_child(sound_button)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(24, 54)
	health_bar.size = Vector2(205, 20)
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	root.add_child(health_bar)
	var health_text := Label.new()
	health_text.name = "HealthText"
	health_text.text = "صحة"
	health_text.position = Vector2(24, 76)
	root.add_child(health_text)
	ammo_label = Label.new()
	ammo_label.text = "30 / 120"
	ammo_label.position = Vector2(-180, -80)
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.add_theme_font_size_override("font_size", 24)
	ammo_label.add_theme_color_override("font_color", Color("fff4da"))
	root.add_child(ammo_label)
	fire_button = _button(root, "إطلاق", Vector2(-125, -172), Vector2(105, 105), Color("a84431"), true)
	fire_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_button.position = Vector2(-132, -160)
	reload_button = _button(root, "تلقيم", Vector2(-142, -62), Vector2(94, 52), Color("4c594b"), false)
	reload_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	reload_button.position = Vector2(-148, -68)
	reload_button.pressed.connect(reload_requested.emit)
	var instruction := Label.new()
	instruction.text = "يسار الشاشة للحركة  •  اسحب اليمين للتصويب"
	instruction.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	instruction.position = Vector2(-180, -18)
	instruction.add_theme_color_override("font_color", Color(0.96, 0.92, 0.8, 0.72))
	root.add_child(instruction)
	# A persistent thumb pad makes the movement area discoverable before the first touch.
	joystick_base = Panel.new()
	joystick_base.position = Vector2(58, -218)
	joystick_base.size = Vector2(142, 142)
	joystick_base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.12, 0.15, 0.13, 0.34)
	base_style.border_color = Color(0.86, 0.82, 0.70, 0.48)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(71)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	root.add_child(joystick_base)
	joystick_knob = Panel.new()
	joystick_knob.size = Vector2(58, 58)
	joystick_knob.position = Vector2(42, 42)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.83, 0.80, 0.68, 0.56)
	knob_style.set_corner_radius_all(29)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)

func _button(parent: Control, caption: String, _unused: Vector2, size: Vector2, color: Color, hold_fire: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.size = size
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.78)
	style.corner_radius_top_left = 48 if hold_fire else 14
	style.corner_radius_top_right = 48 if hold_fire else 14
	style.corner_radius_bottom_left = 48 if hold_fire else 14
	style.corner_radius_bottom_right = 48 if hold_fire else 14
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	parent.add_child(button)
	if hold_fire:
		button.button_down.connect(_start_fire)
		button.button_up.connect(_stop_fire)
	return button

func _input(event: InputEvent) -> void:
	var size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.y > size.y - 190.0 and event.position.x > size.x - 190.0:
				return
			if event.position.x < size.x * 0.43 and move_touch == -1:
				move_touch = event.index
				move_origin = event.position
				joystick_base.position = Vector2(clampf(event.position.x - 71.0, 16.0, size.x * 0.43 - 142.0), -218.0)
				joystick_knob.position = Vector2(42, 42)
			elif event.position.x > size.x * 0.58 and look_touch == -1:
				look_touch = event.index
		else:
			if event.index == move_touch:
				move_touch = -1
				move_changed.emit(Vector2.ZERO)
				joystick_base.position = Vector2(58, -218)
				joystick_knob.position = Vector2(42, 42)
			if event.index == look_touch:
				look_touch = -1
	elif event is InputEventScreenDrag:
		if event.index == move_touch:
			var delta := (event.position - move_origin) / 65.0
			var clamped := Vector2(clampf(delta.x, -1, 1), clampf(delta.y, -1, 1))
			joystick_knob.position = Vector2(42, 42) + clamped * 38.0
			move_changed.emit(clamped)
		elif event.index == look_touch:
			look_delta.emit(event.relative * 0.0024)

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
		health_bar.modulate = Color("d85c45") if value < 35 else Color.WHITE

func set_ammo(current: int, reserve: int) -> void:
	if is_instance_valid(ammo_label):
		ammo_label.text = "%02d / %03d" % [current, reserve]
