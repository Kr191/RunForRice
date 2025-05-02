extends Node2D

enum Choice { ROCK, PAPER, SCISSORS }

var player_choices: Dictionary = {}
var current_round: int = 0
var game_ui: CanvasLayer
var waiting_for_choice: bool = true

func _ready() -> void:
	game_ui = %GameUI
	if not game_ui:
		print("WARNING: GameUI not found!")
		
	var objective = $ChickenRice
	objective.connect("game_over",Callable(self, "_on_game_over"))
	
	MultiplayerManager.register_game_scene($MultiplayerSpawner, $SpawnPoints)
	start_new_round()

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if multiplayer.is_server():
			MultiplayerManager.terminate_host_session()
		# Then safely quit
		get_tree().quit()
		
func start_new_round() -> void:
	player_choices.clear()
	waiting_for_choice = true
	
	# RESET UI for everyone!
	reset_ui.rpc()
	
	# ENABLE BUTTONS for everyone!
	enable_all_player_choice_buttons.rpc()

	print("\n=== New Round ===")

	
func register_player_choice(player_id: int, choice: int) -> void:
	player_choices[player_id] = choice
	print("Player %s chose %s" % [player_id, _choice_to_string(choice)])
	
	if player_choices.size() == MultiplayerManager.get_player_count():
		finish_round()

func finish_round() -> void:
	waiting_for_choice = false
	disable_all_player_choice_buttons()
	determine_winner()

	await get_tree().create_timer(2.0).timeout
	start_new_round()

func determine_winner() -> void:
	var players = player_choices.keys()
	if players.size() < 2:
		print("Not enough players to determine winner.")
		return

	current_round += 1
	
	var p1_id = players[0]
	var p2_id = players[1]
	var p1_choice = player_choices[p1_id]
	var p2_choice = player_choices[p2_id]

	var winner_id := -1
	
	if p1_choice == p2_choice:
		print("It's a Tie!")
	elif (p1_choice == Choice.ROCK and p2_choice == Choice.SCISSORS) or \
		 (p1_choice == Choice.PAPER and p2_choice == Choice.ROCK) or \
		 (p1_choice == Choice.SCISSORS and p2_choice == Choice.PAPER):
		winner_id = p1_id
	else:
		winner_id = p2_id

	print("Winner is: Player ", winner_id)
	
	announce_round_winner.rpc(winner_id)

	if winner_id != -1:
		var winner = _get_player_by_id(winner_id)
		if winner and winner.has_method("move_forward"):
			winner.move_forward()

func _get_player_by_id(id: int) -> Node:
	for player in $MultiplayerSpawner.get_children():
		if player.player_id == id:
			return player
	return null

func _on_game_over(winner_id: int) -> void:
	print("Game Over! Player %d wins!" % winner_id)
	announce_game_winner.rpc(winner_id)
	await get_tree().create_timer(2.0).timeout

	# Tell all clients to return to menu (via rpc)
	_return_to_menu.rpc()

	# Server terminates itself
	if multiplayer.is_server():
		MultiplayerManager.terminate_host_session()

@rpc("any_peer", "call_local", "reliable")
func announce_round_winner(winner_id: int) -> void:
	if not game_ui:
		print("ERROR: GameUI not found!")
		return
		
	var winner_label = game_ui.get_node("Winner")
	
	if winner_id == -1:
		winner_label.text = "It's a Tie!"
	elif winner_id == multiplayer.get_unique_id():
		winner_label.text = "You Won the Round!"
	else:
		winner_label.text = "You Lost the Round!"

@rpc("any_peer", "call_local", "reliable")
func announce_game_winner(winner_id: int) -> void:
	if not game_ui:
		print("ERROR: GameUI not found!")
		return
		
	var winner_label = game_ui.get_node("Winner")
	
	if winner_id == multiplayer.get_unique_id():
		winner_label.text = "You are the Champion!"
	else:
		winner_label.text = "Better luck next time!"

@rpc("any_peer", "call_local", "reliable")
func sync_choice_to_server(player_id: int, choice: int) -> void:
	var sender_id := player_id
	
	if not multiplayer.is_server():
		print("Only server can register choices.")
		return
	
	if multiplayer.get_remote_sender_id() != 0:
		sender_id = multiplayer.get_remote_sender_id()
	
	register_player_choice(sender_id, choice)

@rpc("any_peer", "call_local", "reliable")
func reset_ui() -> void:
	if not game_ui:
		print("ERROR: GameUI not found!")
		return
		
	var choice_label = game_ui.get_node("ChoiceLabel")
	var winner_label = game_ui.get_node("Winner")
	
	choice_label.text = ""
	winner_label.text = ""

@rpc("any_peer", "call_local", "reliable")
func enable_all_player_choice_buttons() -> void:
	for player in $MultiplayerSpawner.get_children():
		if player.has_method("enable_choice_buttons"):
			player.enable_choice_buttons()
		
@rpc("any_peer", "call_local", "reliable")
func _return_to_menu() -> void:
	print("Returning to menu...")

	# Free all players first
	if MultiplayerManager.current_multiplayer_spawner:
		for player in MultiplayerManager.current_multiplayer_spawner.get_children():
			player.queue_free()
	MultiplayerManager.players.clear()

	# Show HUD/MenuPanel again
	var hud := get_node("GameUI/HUD")
	hud.visible = true
	var menu_panel = hud.get_node_or_null("MenuPanel")
	if menu_panel:
		menu_panel.visible = true

func disable_all_player_choice_buttons() -> void:
	for player in $MultiplayerSpawner.get_children():
		if player.has_method("disable_choice_buttons"):
			player.disable_choice_buttons()

func _choice_to_string(choice: int) -> String:
	match choice:
		Choice.ROCK: return "Rock"
		Choice.PAPER: return "Paper"
		Choice.SCISSORS: return "Scissors"
		_: return "Invalid"
