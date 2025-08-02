extends CharacterBody2D

# ─── Signals ────────────────────────────────────────────────────
signal player_died

# ─── Movement & Combat ────────────────────────────────────────────
@export var acceleration: float = 1200.0
@export var friction: float = 800.0
@export var max_speed: float = 200.0
@export var bullet_scene: PackedScene
@export var hat_scene: PackedScene  # Hat scene for P2
@export var gun_scene: PackedScene  # Gun scene for P1

# ─── Aiming Settings ──────────────────────────────────────────────
@export_group("Aiming Settings")
@export var aim_angle_range: float = 22.5  # Degrees up/down from horizontal
@export var aim_deadzone: float = 0.3
@export var aim_smoothing: float = 0.15

# ─── Sprite Settings ──────────────────────────────────────────────
@export_group("Sprite Settings")
@export var sprite_texture: Texture2D
@export var death_sprite_texture: Texture2D  # Sprite to show when player dies

# ─── Player Identification ──────────────────────────────────────────
@export_group("Player Settings")
@export var player_number: int = 1  # 1 for P1, 2 for P2

# ─── Input Actions ────────────────────────────────────────────────
@export_group("Input Actions")
@export var move_left_action: String = "move_left"
@export var move_right_action: String = "move_right"
@export var move_up_action: String = "move_up"
@export var move_down_action: String = "move_down"
@export var fire_action: String = "fire"
@export var reload_action: String = "reload"

# ─── Ammo & Reload ────────────────────────────────────────────────
@export_group("Ammo Settings")
@export var max_ammo: int = 6
@export var reload_time: float = 3.0
@export var fire_rate: float = 0.5  # Time between shots

var ammo_count: int = max_ammo
var reload_timer: float = 0.0
var reloading: bool = false
var fire_cooldown: float = 0.0

# ─── Aiming State ────────────────────────────────────────────────
var current_aim_angle: float = 0.0  # -22.5 to 22.5 degrees
var aim_direction: Vector2 = Vector2.RIGHT

# ─── Power-ups ────────────────────────────────────────────────────
enum PowerUpType {
	RAPID_FIRE,      # Faster fire rate
	LASER_SIGHT,     # Show aim trajectory
	SHIELD,          # Block one shot
	BIG_MAG          # 20 bullets temporarily
}

var active_powerups: Dictionary = {}
var has_shield: bool = false
var original_max_ammo: int = 6

# ─── Game State ────────────────────────────────────────────────────
var alive: bool = true
var can_move: bool = false
var initial_position: Vector2

# ─── Random Number Generator ──────────────────────────────────────
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ─── Internal state ────────────────────────────────────────────────
var sprite: Sprite2D
var gun_sprite: Sprite2D
var shield_sprite: Sprite2D
var laser_sight: Line2D
var facing_right: bool = false
var click_player: AudioStreamPlayer2D
var fire_player: AudioStreamPlayer2D
var reload_player: AudioStreamPlayer2D
var dead_player: AudioStreamPlayer2D

var area_2d: Area2D

func _ready() -> void:
	# Initialize RNG
	rng.randomize()
	
	# Store initial position
	initial_position = global_position
	original_max_ammo = max_ammo
	
	# Cache nodes
	sprite = $Sprite2D as Sprite2D
	gun_sprite = $GunSprite as Sprite2D
	shield_sprite = $ShieldSprite as Sprite2D
	laser_sight = $LaserSight as Line2D
	click_player = $ClickPlayer as AudioStreamPlayer2D
	fire_player = $FirePlayer as AudioStreamPlayer2D
	reload_player = $ReloadPlayer as AudioStreamPlayer2D
	dead_player = $DeadPlayer as AudioStreamPlayer2D
	
	area_2d = $Area2D as Area2D
	
	# Apply texture if one is set
	if sprite_texture and sprite:
		sprite.texture = sprite_texture
	
	# Initially hide shield and laser sight
	if shield_sprite:
		shield_sprite.visible = false
	if laser_sight:
		laser_sight.visible = false
		laser_sight.default_color = Color(1, 0, 0, 0.5)
		laser_sight.width = 2.0
	
	# Connect area signal for hit detection
	if area_2d:
		area_2d.area_entered.connect(_on_area_entered)
		
	#P1 starts facing right
	if player_number == 1:
		facing_right = true
		sprite.flip_h = facing_right
		print("Flipped it")

func _physics_process(delta: float) -> void:
	if not alive or not can_move:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	
	# Get input
	var input_vector: Vector2 = Vector2.ZERO
	
	if Input.is_action_pressed(move_right_action):
		input_vector.x += 1.0
	if Input.is_action_pressed(move_left_action):
		input_vector.x -= 1.0
	if Input.is_action_pressed(move_down_action):
		input_vector.y += 1.0
	if Input.is_action_pressed(move_up_action):
		input_vector.y -= 1.0
	
	# Update facing direction
	if input_vector.x > 0.0:
		facing_right = true
	elif input_vector.x < 0.0:
		facing_right = false
	
	# Update sprite flip
	sprite.flip_h = facing_right
	if gun_sprite:
		gun_sprite.flip_h = facing_right
	
	# Apply movement with acceleration and friction
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		velocity = velocity.move_toward(input_vector * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	# Apply movement boundaries after movement
	_apply_movement_boundaries()
	
	# Update aiming
	_update_aiming(delta)
	
	# Update power-up timers
	_update_powerups(delta)

func _process(delta: float) -> void:
	if not alive or not can_move:
		return
	
	# Handle fire cooldown
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	# Handle reload countdown
	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			reloading = false
			ammo_count = max_ammo
	
	# Manual reload input
	if not reloading and ammo_count < max_ammo and Input.is_action_just_pressed(reload_action):
		_start_reload()
	
	# Fire input
	var should_fire = false
	if active_powerups.has(PowerUpType.RAPID_FIRE):
		should_fire = Input.is_action_pressed(fire_action) and fire_cooldown <= 0
	else:
		should_fire = Input.is_action_just_pressed(fire_action)
	
	if should_fire:
		if reloading:
			return
		
		if ammo_count > 0:
			_fire()
			ammo_count -= 1
			# Set fire cooldown
			if active_powerups.has(PowerUpType.RAPID_FIRE):
				fire_cooldown = 0.1  # Very fast fire rate
			else:
				fire_cooldown = fire_rate
		else:
			# Play empty-gun click with random pitch
			var pitch: float = rng.randf_range(0.8, 1.2)
			click_player.pitch_scale = pitch
			click_player.play()

func _update_aiming(delta: float) -> void:
	# Get right stick input
	var device = 0 if player_number == 1 else 1
	var aim_y = Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	
	# Apply deadzone
	if abs(aim_y) < aim_deadzone:
		aim_y = 0.0
	
	# Calculate target angle (-1 to 1 maps to -aim_angle_range to aim_angle_range)
	var target_angle = aim_y * aim_angle_range
	
	# Smooth the aiming
	current_aim_angle = lerp(current_aim_angle, target_angle, aim_smoothing)
	
	# Update aim direction based on facing
	var base_direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	aim_direction = base_direction.rotated(deg_to_rad(current_aim_angle))
	
	# Update gun sprite rotation
	if gun_sprite:
		gun_sprite.rotation_degrees = current_aim_angle
		if not facing_right:
			gun_sprite.rotation_degrees = 180 - current_aim_angle
		
		# Position gun sprite
		var gun_offset = Vector2(5 if facing_right else -5, 0)
		gun_sprite.position = gun_offset
	
	# Update laser sight if active
	if laser_sight and active_powerups.has(PowerUpType.LASER_SIGHT):
		laser_sight.visible = true
		laser_sight.clear_points()
		laser_sight.add_point(Vector2.ZERO)
		laser_sight.add_point(aim_direction * 300)
	elif laser_sight:
		laser_sight.visible = false

func _update_powerups(delta: float) -> void:
	# Update powerup timers
	var expired_powerups = []
	for powerup_type in active_powerups:
		active_powerups[powerup_type] -= delta
		if active_powerups[powerup_type] <= 0:
			expired_powerups.append(powerup_type)
	
	# Remove expired powerups
	for powerup_type in expired_powerups:
		_remove_powerup(powerup_type)

func add_powerup(type: PowerUpType, duration: float = 10.0) -> void:
	active_powerups[type] = duration
	
	match type:
		PowerUpType.SHIELD:
			has_shield = true
			if shield_sprite:
				shield_sprite.visible = true
		PowerUpType.BIG_MAG:
			max_ammo = 20
			ammo_count = 20

func _remove_powerup(type: PowerUpType) -> void:
	active_powerups.erase(type)
	
	match type:
		PowerUpType.SHIELD:
			has_shield = false
			if shield_sprite:
				shield_sprite.visible = false
		PowerUpType.BIG_MAG:
			max_ammo = original_max_ammo
			if ammo_count > max_ammo:
				ammo_count = max_ammo

func _start_reload() -> void:
	reloading = true
	reload_timer = reload_time
	
	# Play reload sound with random pitch
	var pitch: float = rng.randf_range(0.8, 1.2)
	reload_player.pitch_scale = pitch
	reload_player.play()

func _fire() -> void:
	var bullet: Bullet = bullet_scene.instantiate() as Bullet
	bullet.global_position = global_position
	bullet.shooter = self  # Set the shooter reference
	bullet.direction = aim_direction
	
	# Play fire sound with random pitch
	var pitch: float = rng.randf_range(0.8, 1.2)
	fire_player.pitch_scale = pitch
	fire_player.play()
	
	get_parent().add_child(bullet)

func _on_area_entered(area: Area2D) -> void:
	# Check if it's a bullet from another player
	var bullet = area.get_parent() as Bullet
	if bullet and bullet.shooter != self and alive:
		if has_shield:
			# Block the shot with shield
			has_shield = false
			if shield_sprite:
				shield_sprite.visible = false
			active_powerups.erase(PowerUpType.SHIELD)
			bullet.queue_free()
		else:
			take_hit(bullet)

func take_hit(bullet: Bullet = null) -> void:
	if not alive:
		return
	
	alive = false
	can_move = false
	
	# Launch appropriate item based on player
	if player_number == 1 and gun_scene:
		_launch_gun(bullet)
	elif player_number == 2 and hat_scene:
		_launch_hat(bullet)
	
	# Play death animation (simple fade out)
	_play_death_animation()
	
	# Emit death signal
	player_died.emit()
	$DeadPlayer.play()

func _launch_gun(bullet: Bullet = null) -> void:
	var gun: Gun = gun_scene.instantiate() as Gun
	get_parent().add_child(gun)
	
	# Position gun at player's position
	var gun_position = global_position
	# Force gun to fly left
	gun.launch(gun_position, true)

func _launch_hat(bullet: Bullet = null) -> void:
	var hat: Hat = hat_scene.instantiate() as Hat
	get_parent().add_child(hat)
	
	# Position hat slightly above player's head
	var hat_position = global_position + Vector2(0, -10)
	# Force hat to fly right
	hat.launch(hat_position, Vector2(1, -1).normalized())

func _play_death_animation() -> void:
	# Simple death animation - just change to death sprite
	if death_sprite_texture and sprite:
		sprite.texture = death_sprite_texture
	# Hide gun sprite on death
	if gun_sprite:
		gun_sprite.visible = false

func reset_for_new_round() -> void:
	alive = true
	can_move = false
	reloading = false
	reload_timer = 0.0
	ammo_count = max_ammo
	fire_cooldown = 0.0
	current_aim_angle = 0.0
	
	# Clear all powerups
	active_powerups.clear()
	has_shield = false
	max_ammo = original_max_ammo
	if shield_sprite:
		shield_sprite.visible = false
	if laser_sight:
		laser_sight.visible = false
	
	# Reset position
	global_position = initial_position
	velocity = Vector2.ZERO
	
	# Reset sprite to alive texture
	if sprite_texture and sprite:
		sprite.texture = sprite_texture
	if gun_sprite:
		gun_sprite.visible = true
		gun_sprite.rotation_degrees = 0
	
	# Reset facing direction
	#P1 starts facing right
	if player_number == 1:
		facing_right = true
	else:
		facing_right = false
		sprite.flip_h = facing_right

func set_can_move(enabled: bool) -> void:
	can_move = enabled

func _apply_movement_boundaries() -> void:
	# Map boundaries (based on the TextureRect in game.tscn)
	var map_left: float = 10.0  # Left boundary with padding
	var map_right: float = 310.0  # Right boundary with padding
	var map_top: float = 10.0  # Top boundary with padding
	var map_bottom: float = 175.0  # Bottom boundary with padding
	var map_center_x: float = 160.0  # Center divide
	
	# Apply vertical boundaries (same for both players)
	global_position.y = clamp(global_position.y, map_top, map_bottom)
	
	# Apply horizontal boundaries based on player
	if player_number == 1:
		# Player 1 confined to left side
		global_position.x = clamp(global_position.x, map_left, map_center_x - 5.0)
	else:
		# Player 2 confined to right side
		global_position.x = clamp(global_position.x, map_center_x + 5.0, map_right)
