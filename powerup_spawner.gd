extends Node2D
class_name PowerUpSpawner

@export var powerup_scene: PackedScene
@export var spawn_positions: Array[Vector2] = [
	Vector2(80, 50),   # Top left
	Vector2(240, 50),  # Top right
	Vector2(80, 130),  # Bottom left
	Vector2(240, 130), # Bottom right
	Vector2(160, 90)   # Center
]
@export var initial_spawn_delay: float = 5.0
@export var spawn_interval: float = 20.0

var spawn_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var active_powerups: Array[PowerUp] = []

# Import the PowerUpType enum
enum PowerUpType {
	RAPID_FIRE,
	LASER_SIGHT,
	SHIELD,
	BIG_MAG
}

func _ready() -> void:
	rng.randomize()
	spawn_timer = initial_spawn_delay

func _process(delta: float) -> void:
	spawn_timer -= delta
	
	if spawn_timer <= 0:
		spawn_powerup()
		spawn_timer = spawn_interval

func spawn_powerup() -> void:
	if not powerup_scene:
		return
	
	# Choose random spawn position
	var spawn_pos = spawn_positions[rng.randi() % spawn_positions.size()]
	
	# Check if position is already occupied
	for powerup in active_powerups:
		if powerup and is_instance_valid(powerup) and powerup.global_position.distance_to(spawn_pos) < 20:
			return  # Don't spawn on top of existing powerup
	
	# Create powerup
	var powerup: PowerUp = powerup_scene.instantiate() as PowerUp
	
	# Set random type
	var types = [PowerUpType.RAPID_FIRE, PowerUpType.LASER_SIGHT, PowerUpType.SHIELD, PowerUpType.BIG_MAG]
	powerup.powerup_type = types[rng.randi() % types.size()]
	
	# Set position and add to scene
	add_child(powerup)
	powerup.global_position = spawn_pos
	active_powerups.append(powerup)
	
	# Clean up null references
	active_powerups = active_powerups.filter(func(p): return p != null and is_instance_valid(p))

func clear_all_powerups() -> void:
	for powerup in active_powerups:
		if powerup and is_instance_valid(powerup):
			powerup.queue_free()
	active_powerups.clear()
	spawn_timer = initial_spawn_delay
