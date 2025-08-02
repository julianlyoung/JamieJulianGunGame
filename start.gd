extends Node2D

@onready var music: AudioStreamPlayer = $Music
@onready var intro_anim: AnimationPlayer = $Intro

var _game_started: bool = false

func _ready() -> void:
	# Wait for five seconds, then play background music
	await get_tree().create_timer(5.0).timeout
	music.play()

func _process(delta: float) -> void:
	if _game_started:
		return

	# Check for either player’s “fire” action
	if Input.is_action_just_pressed("P1Fire") or Input.is_action_just_pressed("P2Fire"):
		_start_game()

func _start_game() -> void:
	_game_started = true
	# Play the “Start” intro animation
	intro_anim.play("Start")
	# Wait for the animation to finish
	await intro_anim.animation_finished
	# Change to Game.tscn
	var game_scene: PackedScene = ResourceLoader.load("res://game.tscn") as PackedScene
	get_tree().change_scene_to_file("res://Game.tscn")
