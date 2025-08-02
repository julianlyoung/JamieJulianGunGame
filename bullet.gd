extends Node2D
class_name Bullet

@export var speed: float = 400.0
var direction: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	# Auto-free when off-screen
	var view_rect: Rect2 = get_viewport().get_visible_rect()
	if not view_rect.has_point(global_position):
		queue_free()
