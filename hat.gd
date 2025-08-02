extends Node2D
class_name Hat

@export var initial_velocity: Vector2 = Vector2(100, -150)
@export var gravity: float = 300.0
@export var spin_speed: float = 720.0  # degrees per second
@export var lifetime: float = 5.0

var velocity: Vector2
var spin_direction: int = 1  # 1 for clockwise, -1 for counter-clockwise
var time_alive: float = 0.0

func _ready() -> void:
	velocity = initial_velocity
	# Randomize spin direction
	spin_direction = 1 if randf() > 0.5 else -1
	
	# Add some random variation to the initial velocity
	velocity.x += randf_range(-50, 50)
	velocity.y += randf_range(-50, 25)

func _physics_process(delta: float) -> void:
	# Apply gravity to vertical velocity
	velocity.y += gravity * delta
	
	# Move the hat
	global_position += velocity * delta
	
	# Spin the hat
	rotation_degrees += spin_speed * spin_direction * delta
	
	# Track lifetime
	time_alive += delta
	
	# Auto-cleanup after lifetime or when off-screen
	if time_alive >= lifetime or _is_off_screen():
		queue_free()

func _is_off_screen() -> bool:
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 100  # Extra margin to ensure hat is completely off-screen
	
	return (global_position.x < -margin or 
			global_position.x > viewport_size.x + margin or
			global_position.y > viewport_size.y + margin)

func launch(from_position: Vector2, launch_direction: Vector2 = Vector2.ZERO) -> void:
	global_position = from_position
	
	# If no specific direction provided, use a default upward launch
	if launch_direction == Vector2.ZERO:
		launch_direction = Vector2(randf_range(-1, 1), -1).normalized()
	
	# Set the velocity based on launch direction
	var speed = initial_velocity.length()
	velocity = launch_direction * speed
	
	# For rightward flight (P2's hat), ensure positive X velocity
	if launch_direction.x > 0:
		velocity.x = abs(velocity.x) + randf_range(80, 150)  # Force rightward
		velocity.y = randf_range(-120, -60)  # Upward momentum
	else:
		velocity.y = min(velocity.y, -100)  # Ensure some upward momentum
