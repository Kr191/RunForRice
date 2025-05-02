class_name Player
extends CharacterBody2D

@export var player_id := 1
@onready var animated_sprite = $AnimatedSprite2D
var direction

var rock_button : Button = null
var paper_button : Button = null
var scissors_button : Button = null
var submit_button : Button = null

func _ready():
	
	if player_id == 1:
		direction = 1
	else:
		direction = -1
	
	# Flip the sprite if moving left
	animated_sprite.flip_h = direction < 0
	
	print("Player ready! ID:", player_id, " Facing:", direction)
	
	if multiplayer.get_unique_id() == player_id:
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false
		
	rock_button = $UI/UserUI/HBoxContainer/Rock
	paper_button = $UI/UserUI/HBoxContainer/Paper
	scissors_button = $UI/UserUI/HBoxContainer/Scissors
	submit_button = $UI/UserUI/Submit
	print("UI ready with ID:", player_id)
	


func disable_choice_buttons() -> void:
	if rock_button and paper_button and scissors_button and submit_button:
		rock_button.disabled = true
		paper_button.disabled = true
		scissors_button.disabled = true
		submit_button.disabled = true

func enable_choice_buttons() -> void:
	if rock_button and paper_button and scissors_button and submit_button:
		rock_button.disabled = false
		paper_button.disabled = false
		scissors_button.disabled = false
		submit_button.disabled = false
		
# Called when the player wins a round
func move_forward():
	var target_position = position + Vector2(120 * direction, 0)
	_move_to_position(target_position)
	move_forward_remote.rpc(target_position)

# Local helper to move smoothly
func _move_to_position(target_pos: Vector2):
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, 0.5)

# Remote move syncing to all players
@rpc("any_peer","call_local", "reliable")
func move_forward_remote(target_position: Vector2):
	_move_to_position(target_position)
