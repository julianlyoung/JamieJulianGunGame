extends Node
class_name GameController

signal round_started
signal round_ended(winner_player_number: int)
signal game_ended(winner_player_number: int)

@export var rounds_to_win: int = 2  # Best of 3 = first to 2 wins
@export var round_start_delay: float = 2.0
@export var round_end_delay: float = 3.0
@export var game_restart_countdown: float = 5.0

# Game state
enum GameState { WAITING, ROUND_STARTING, FIGHTING, ROUND_ENDING, GAME_OVER, RESTARTING }
var current_state: GameState = GameState.WAITING
var current_round: int = 1
var player1_score: int = 0
var player2_score: int = 0

# UI References
var round_label: Label
var score_label: Label
var countdown_label: Label

# Player references
var player1: CharacterBody2D
var player2: CharacterBody2D

# PowerUp spawner reference
var powerup_spawner: PowerUpSpawner

# Timers
var state_timer: float = 0.0

func _ready() -> void:
	# Find UI elements and players
	find_game_elements()
	
	# Connect signals
	connect_player_signals()
	
	# Create powerup spawner
	setup_powerup_spawner()
	
	# Start first round
	await get_tree().process_frame  # Wait one frame for everything to be ready
	start_new_round()

func find_game_elements() -> void:
	# Find UI elements
	round_label = get_node("RoundLabel") as Label
	score_label = get_node("ScoreLabel") as Label  
	countdown_label = get_node("CountdownLabel") as Label
	
	# Find players
	player1 = get_node("Player") as CharacterBody2D
	player2 = get_node("Player2") as CharacterBody2D

func setup_powerup_spawner() -> void:
	# Create powerup spawner node
	powerup_spawner = PowerUpSpawner.new()
	powerup_spawner.name = "PowerUpSpawner"
	
	# Load powerup scene
	powerup_spawner.powerup_scene = preload("res://powerup.tscn")
	
	add_child(powerup_spawner)

func connect_player_signals() -> void:
	if player1 and player1.has_signal("player_died"):
		player1.player_died.connect(_on_player_died.bind(1))
	if player2 and player2.has_signal("player_died"):
		player2.player_died.connect(_on_player_died.bind(2))

func _process(delta: float) -> void:
	match current_state:
		GameState.ROUND_STARTING:
			_handle_round_starting(delta)
		GameState.ROUND_ENDING:
			_handle_round_ending(delta)
		GameState.RESTARTING:
			_handle_restarting(delta)

func _handle_round_starting(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		current_state = GameState.FIGHTING
		round_label.text = ""
		enable_players(true)
		round_started.emit()

func _handle_round_ending(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		if player1_score >= rounds_to_win or player2_score >= rounds_to_win:
			end_game()
		else:
			start_new_round()

func _handle_restarting(delta: float) -> void:
	state_timer -= delta
	countdown_label.text = "Game restarts in: " + str(int(state_timer) + 1)
	if state_timer <= 0:
		restart_game()

func start_new_round() -> void:
	current_state = GameState.ROUND_STARTING
	state_timer = round_start_delay
	
	# Clear powerups
	if powerup_spawner:
		powerup_spawner.clear_all_powerups()
	
	# Reset players
	reset_players()
	enable_players(false)
	
	# Update UI
	round_label.text = "ROUND " + str(current_round) + " - FIGHT!"
	$Fight.play()
	update_score_display()
	countdown_label.text = ""

func end_round(winner_player: int) -> void:
	current_state = GameState.ROUND_ENDING
	state_timer = round_end_delay
	
	# Update score
	if winner_player == 1:
		player1_score += 1
	else:
		player2_score += 1
	
	current_round += 1
	enable_players(false)
	
	round_ended.emit(winner_player)

func end_game() -> void:
	current_state = GameState.GAME_OVER
	
	var winner = 1 if player1_score > player2_score else 2
	round_label.text = "WINNER P" + str(winner) + "!"
	
	# Start restart countdown
	current_state = GameState.RESTARTING
	state_timer = game_restart_countdown
	
	game_ended.emit(winner)

func restart_game() -> void:
	current_round = 1
	player1_score = 0
	player2_score = 0
	current_state = GameState.WAITING
	countdown_label.text = ""
	start_new_round()

func reset_players() -> void:
	if player1:
		player1.reset_for_new_round()
	if player2:
		player2.reset_for_new_round()

func enable_players(enabled: bool) -> void:
	if player1:
		player1.set_can_move(enabled)
	if player2:
		player2.set_can_move(enabled)

func update_score_display() -> void:
	score_label.text = str(player1_score) + " - " + str(player2_score)

func _on_player_died(player_number: int) -> void:
	if current_state == GameState.FIGHTING:
		var winner = 2 if player_number == 1 else 1
		end_round(winner)
