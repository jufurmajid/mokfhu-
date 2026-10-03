extends Node3D
const SPEED := 78.0
const LIFE := 2.3
var target := Vector3.ZERO
var player: Node3D
var combat_audio: Node
var direction := Vector3.FORWARD
var age := 0.0
var whiz_played := false

func _ready() -> void:
	direction = (target - global_position).normalized()

func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	var step := direction * SPEED * delta
	var previous := global_position
	var next := previous + step
	var query := PhysicsRayQueryParameters3D.create(previous, next)
	query.exclude = []
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		if hit.collider == player:
			player.call("take_damage", 12, global_position)
		queue_free()
		return
	global_position = next
	if is_instance_valid(player) and not whiz_played:
		var closest := Geometry3D.get_closest_point_to_segment(player.global_position + Vector3(0, 1.0, 0), previous, next)
		var separation := closest.distance_to(player.global_position + Vector3(0, 1.0, 0))
		if separation < 2.4:
			combat_audio.call("play_bullet_whiz", closest, clampf(1.0 - separation / 2.4, 0.0, 1.0))
			whiz_played = true
