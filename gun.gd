extends Node2D
class_name Gun

@export var initial_velocity: Vector2 = Vector2(-120, -100)  # Default leftward velocity
@export var gravity: float = 300.0
@export var spin_speed: float = 540.0  # degrees per second (slightly slower than hat)
@export var lifetime: float = 5.0

var velocity: Vector2
var spin_direction: int = 1  # 1 for clockwise, -1 for counter-clockwise
var time_alive: float = 0.0

func _ready() -> void:
	velocity = initial_velocity
	# Randomize spin direction
	spin_direction = 1 if randf() > 0.5 else -1
	
	# Add some random variation to the initial velocity
	velocity.x += randf_range(-30, 30)
	velocity.y += randf_range(-25, 25)

func _physics_process(delta: float) -> void:
	# Apply gravity to vertical velocity
	velocity.y += gravity * delta
	
	# Move the gun
	global_position += velocity * delta
	
	# Spin the gun
	rotation_degrees += spin_speed * spin_direction * delta
	
	# Track lifetime
	time_alive += delta
	
	# Auto-cleanup after lifetime or when off-screen
	if time_alive >= lifetime or _is_off_screen():
		queue_free()

func _is_off_screen() -> bool:
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 100  # Extra margin to ensure gun is completely off-screen
	
	return (global_position.x < -margin or 
			global_position.x > viewport_size.x + margin or
			global_position.y > viewport_size.y + margin)

func launch(from_position: Vector2, force_left: bool = false) -> void:
	global_position = from_position
	
	# Force leftward direction for Player 1's gun
	if force_left:
		velocity = Vector2(randf_range(-150, -80), randf_range(-120, -60))
	else:
		velocity = initial_velocity
		# Add random variation
		velocity.x += randf_range(-30, 30)
		velocity.y += randf_range(-25, 25)
	
	# Ensure some upward momentum
	velocity.y = min(velocity.y, -50)
