extends CharacterBody2D

@export var speed: float = 200.0
@export var bullet_scene: PackedScene

@export var move_left_action: String
@export var move_right_action: String
@export var move_up_action: String
@export var move_down_action: String
@export var fire_action: String
@export var reload_action: String      # action to start reload

# ─── Ammo & Reload ────────────────────────────────────────────────
@export var max_ammo: int = 6
@export var reload_time: float = 3.0
var ammo_count: int = max_ammo
var reload_timer: float = 0.0
var reloading: bool = false

# ─── Random Number Generator ──────────────────────────────────────
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ─── Internal state ────────────────────────────────────────────────
var sprite: Sprite2D
var facing_right: bool = false
var click_player: AudioStreamPlayer2D
var fire_player: AudioStreamPlayer2D
var reload_player: AudioStreamPlayer2D

func _ready() -> void:
	# Initialise RNG
	rng.randomize()

	# Cache nodes
	sprite = $Sprite2D as Sprite2D
	click_player = $ClickPlayer as AudioStreamPlayer2D
	fire_player = $FirePlayer as AudioStreamPlayer2D
	reload_player = $ReloadPlayer as AudioStreamPlayer2D

func _physics_process(delta: float) -> void:
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

	sprite.flip_h = facing_right

	# Move logic
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized() * speed

	velocity = input_vector
	move_and_slide()

func _process(delta: float) -> void:
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
			# play empty‑gun click with random pitch
			var pitch: float = rng.randf_range(0.8, 1.2)
			click_player.pitch_scale = pitch
			click_player.play()

func _start_reload() -> void:
	reloading = true
	reload_timer = reload_time
	# play reload sound with random pitch
	var pitch: float = rng.randf_range(0.8, 1.2)
	reload_player.pitch_scale = pitch
	reload_player.play()

func _fire() -> void:
	var bullet: Bullet = bullet_scene.instantiate() as Bullet
	bullet.global_position = global_position

	if facing_right:
		bullet.direction = Vector2.RIGHT
	else:
		bullet.direction = Vector2.LEFT

	# play fire sound with random pitch
	var pitch: float = rng.randf_range(0.8, 1.2)
	fire_player.pitch_scale = pitch
	fire_player.play()

	get_parent().add_child(bullet)
