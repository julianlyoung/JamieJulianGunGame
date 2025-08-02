extends Area2D
class_name PowerUp

# Import the PowerUpType enum
enum PowerUpType {
	RAPID_FIRE,      # Faster fire rate
	LASER_SIGHT,     # Show aim trajectory
	SHIELD,          # Block one shot
	BIG_MAG          # 20 bullets temporarily
}

@export var powerup_type: PowerUpType = PowerUpType.RAPID_FIRE
@export var duration: float = 10.0
@export var move_speed: float = 50.0  # Speed for moving across screen

var collected: bool = false
var move_direction: int = 0  # 1 for down, -1 for up

# Visual components
var sprite: Sprite2D
var particles: CPUParticles2D

func _ready() -> void:
	# Cache components
	sprite = $Sprite2D as Sprite2D
	particles = $CPUParticles2D as CPUParticles2D
	
	# Set up visual based on powerup type
	_setup_visual()
	
	# Connect to area entered signal
	area_entered.connect(_on_area_entered)
	
	# Set collision
	collision_layer = 8  # PowerUp layer
	collision_mask = 2   # Detect players

func _setup_visual() -> void:
	if not sprite:
		return
	
	# Set color and icon based on type
	match powerup_type:
		PowerUpType.RAPID_FIRE:
			sprite.modulate = Color(1, 0.5, 0)  # Orange
		PowerUpType.LASER_SIGHT:
			sprite.modulate = Color(1, 0, 0)    # Red
		PowerUpType.SHIELD:
			sprite.modulate = Color(0, 0.5, 1)  # Blue
		PowerUpType.BIG_MAG:
			sprite.modulate = Color(0.5, 0, 0.5)  # Purple
	
	# Setup particles
	if particles:
		particles.emitting = true
		particles.color = sprite.modulate

func _physics_process(delta: float) -> void:
	if collected:
		return
	
	# Move across screen
	global_position.y += move_direction * move_speed * delta
	
	# Rotate slowly
	if sprite:
		sprite.rotation_degrees += 90 * delta
	
	# Check if off screen and remove
	var viewport_size = get_viewport().get_visible_rect().size
	if move_direction > 0 and global_position.y > viewport_size.y + 20:
		queue_free()
	elif move_direction < 0 and global_position.y < -20:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if collected:
		return
	
	# Check if it's a player
	var player = area.get_parent()
	if player and player.has_method("add_powerup"):
		# Give powerup to player
		player.add_powerup(powerup_type, duration)
		
		# Visual feedback and removal
		collected = true
		queue_free()

func setup_movement(start_from_top: bool) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	
	if start_from_top:
		global_position.y = -20
		move_direction = 1  # Move down
	else:
		global_position.y = viewport_size.y + 20
		move_direction = -1  # Move up
	
	# Always spawn at horizontal center
	global_position.x = 160  # Center of 320 width screen
