extends StaticBody2D
class_name Stone

@export var sprite_texture: Texture2D

var ricochet_sounds: Array[AudioStream] = []
var audio_player: AudioStreamPlayer2D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	
	# Set up sprite
	var sprite = $Sprite2D as Sprite2D
	if sprite and sprite_texture:
		sprite.texture = sprite_texture
	
	# Load ricochet sounds
	ricochet_sounds = [
		preload("res://sounds/rico1.mp3"),
		preload("res://sounds/rico2.mp3"),
		preload("res://sounds/rico3.mp3")
	]
	
	# Create audio player
	audio_player = $AudioStreamPlayer2D as AudioStreamPlayer2D
	
	# Set collision layers
	collision_layer = 1  # Default collision layer so players can collide with it
	collision_mask = 0   # Doesn't need to detect anything
	
	# Connect to bullet detection
	var area = $Area2D as Area2D
	if area:
		area.area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	# Check if it's a bullet
	var bullet = area.get_parent()
	if bullet and bullet.has_method("queue_free"):
		# Play random ricochet sound
		if audio_player and ricochet_sounds.size() > 0:
			var random_sound = ricochet_sounds[rng.randi() % ricochet_sounds.size()]
			audio_player.stream = random_sound
			audio_player.pitch_scale = rng.randf_range(0.9, 1.1)
			audio_player.play()
		
		# Destroy the bullet
		bullet.queue_free()
