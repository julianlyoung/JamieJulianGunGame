extends Node2D
class_name PowerUpSpawner

@export var powerup_scene: PackedScene
@export var spawn_interval_min: float = 15.0
@export var spawn_interval_max: float = 30.0

var spawn_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_powerup: PowerUp = null

# Import the PowerUpType enum
enum PowerUpType {
	RAPID_FIRE,
	LASER_SIGHT,
	SHIELD,
	BIG_MAG
}

func _ready() -> void:
	rng.randomize()
	# Set initial spawn timer to random interval
	spawn_timer = rng.randf_range(spawn_interval_min, spawn_interval_max)

func _process(delta: float) -> void:
	spawn_timer -= delta
	
	if spawn_timer <= 0:
		spawn_powerup()
		# Reset timer with random interval
		spawn_timer = rng.randf_range(spawn_interval_min, spawn_interval_max)

func spawn_powerup() -> void:
	if not powerup_scene:
		return
	
	# Don't spawn if one already exists
	if current_powerup and is_instance_valid(current_powerup):
		return
	
	# Create powerup
	var powerup: PowerUp = powerup_scene.instantiate() as PowerUp
	
	# Set random type
	var types = [PowerUpType.RAPID_FIRE, PowerUpType.LASER_SIGHT, PowerUpType.SHIELD, PowerUpType.BIG_MAG]
	powerup.powerup_type = types[rng.randi() % types.size()]
	
	# Add to scene
	add_child(powerup)
	
	# Set up movement (randomly from top or bottom)
	var from_top = rng.randf() > 0.5
	powerup.setup_movement(from_top)
	
	current_powerup = powerup

func clear_all_powerups() -> void:
	if current_powerup and is_instance_valid(current_powerup):
		current_powerup.queue_free()
	current_powerup = null
	# Reset timer
	spawn_timer = rng.randf_range(spawn_interval_min, spawn_interval_max)
