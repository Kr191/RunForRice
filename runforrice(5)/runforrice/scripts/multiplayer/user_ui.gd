extends Control

enum Choice { ROCK, PAPER, SCISSORS }

var selected_choice: int = -1

func _ready() -> void:
	%Rock.pressed.connect(func(): _on_choice_button_pressed(Choice.ROCK))
	%Paper.pressed.connect(func(): _on_choice_button_pressed(Choice.PAPER))
	%Scissors.pressed.connect(func(): _on_choice_button_pressed(Choice.SCISSORS))
	%Submit.pressed.connect(_on_submit_pressed)

func _on_choice_button_pressed(choice: int) -> void:
	selected_choice = choice
	var choice_label = get_node("/root/Game/GameUI/ChoiceLabel")
	choice_label.text = "Selected: %s" % _choice_to_string(choice)
	print("You selected:", _choice_to_string(choice))

func _on_submit_pressed() -> void:
	if selected_choice == -1:
		print("No choice selected yet!")
		return
		
	var game_node = get_node("/root/Game")
	
	if multiplayer.is_server():
		game_node.sync_choice_to_server(multiplayer.get_unique_id(), selected_choice)
	else:
		game_node.sync_choice_to_server.rpc_id(1, multiplayer.get_unique_id(), selected_choice)
		
	disable_ui_buttons()

func disable_ui_buttons() -> void:
	%Rock.disabled = true
	%Paper.disabled = true
	%Scissors.disabled = true
	%Submit.disabled = true

func enable_ui_buttons() -> void:
	%Rock.disabled = false
	%Paper.disabled = false
	%Scissors.disabled = false
	%Submit.disabled = false

func _choice_to_string(choice: int) -> String:
	match choice:
		Choice.ROCK: return "Rock"
		Choice.PAPER: return "Paper"
		Choice.SCISSORS: return "Scissors"
		_: return "Invalid"
