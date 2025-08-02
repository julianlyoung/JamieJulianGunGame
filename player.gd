extends CharacterBody2D

# ─── Signals ────────────────────────────────────────────────────
signal player_died

# ─── Movement & Combat ────────────────────────────────────────────
@export var speed: float = 200.0
@export var bullet_scene: PackedScene
@export var hat_scene: PackedScene  # Hat scene for P2
@export var gun_scene: PackedScene  # Gun scene for P1

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

var ammo_count: int = max_ammo
var reload_timer: float = 0.0
var reloading: bool = false

# ─── Game State ────────────────────────────────────────────────────
var alive: bool = true
var can_move: bool = false
var initial_position: Vector2

# ─── Random Number Generator ──────────────────────────────────────
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ─── Internal state ────────────────────────────────────────────────
var sprite: Sprite2D
var facing_right: bool = false
var click_player: AudioStreamPlayer2D
var fire_player: AudioStreamPlayer2D
var reload_player: AudioStreamPlayer2D
var area_2d: Area2D

func _ready() -> void:
	# Initialize RNG
	rng.randomize()
	
	# Store initial position
	initial_position = global_position
	
	# Cache nodes
	sprite = $Sprite2D as Sprite2D
	click_player = $ClickPlayer as AudioStreamPlayer2D
	fire_player = $FirePlayer as AudioStreamPlayer2D
	reload_player = $ReloadPlayer as AudioStreamPlayer2D
	area_2d = $Area2D as Area2D
	
	# Apply texture if one is set
	if sprite_texture and sprite:
		sprite.texture = sprite_texture
	
	# Connect area signal for hit detection
	if area_2d:
		area_2d.area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if not alive or not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
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
	
	# Move logic
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized() * speed
	
	velocity = input_vector
	move_and_slide()

func _process(delta: float) -> void:
	if not alive or not can_move:
		return
	
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
	if Input.is_action_just_pressed(fire_action):
		if reloading:
			return
		
		if ammo_count > 0:
			_fire()
			ammo_count -= 1
		else:
			# Play empty-gun click with random pitch
			var pitch: float = rng.randf_range(0.8, 1.2)
			click_player.pitch_scale = pitch
			click_player.play()

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
	
	if facing_right:
		bullet.direction = Vector2.RIGHT
	else:
		bullet.direction = Vector2.LEFT
	
	# Play fire sound with random pitch
	var pitch: float = rng.randf_range(0.8, 1.2)
	fire_player.pitch_scale = pitch
	fire_player.play()
	
	get_parent().add_child(bullet)

func _on_area_entered(area: Area2D) -> void:
	# Check if it's a bullet from another player
	var bullet = area.get_parent() as Bullet
	if bullet and bullet.shooter != self and alive:
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

func reset_for_new_round() -> void:
	alive = true
	can_move = false
	reloading = false
	reload_timer = 0.0
	ammo_count = max_ammo
	
	# Reset position
	global_position = initial_position
	
	# Reset sprite to alive texture
	if sprite_texture and sprite:
		sprite.texture = sprite_texture
	
	# Reset facing direction
	facing_right = false
	sprite.flip_h = false

func set_can_move(enabled: bool) -> void:
	can_move = enabled
