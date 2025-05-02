extends Node

const SERVER_PORT = 8000
const SERVER_IP = 'Host ip' 
const MAX_PLAYERS = 2

var PLAYER = preload("res://scenes/multiplayer_player.tscn")

var host_mode_enabled = false
var multiplayer_mode_enabled = false

var players: Array[Player] = []
var connected_players := []

var current_multiplayer_spawner
var current_spawn_points

signal host_disconnected
signal client_disconnected(peer_id: int)

func register_game_scene(multiplayer_spawner, spawn_points):
	current_multiplayer_spawner = multiplayer_spawner
	current_spawn_points = spawn_points
	
func become_host():
	print("Starting host!")

	multiplayer_mode_enabled = true
	host_mode_enabled = true

	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	multiplayer.multiplayer_peer = server_peer

	# Host listens for new peers and spawns them
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Spawn host player (ID 1 is always host)
	if multiplayer.get_unique_id() == 1:
		add_player_to_game(1)
		
	connected_players.append(1)

func join_as_player_2():
	print("Player 2 joining")

	multiplayer_mode_enabled = true
	
	var client_peer := ENetMultiplayerPeer.new()
	if client_peer.create_client(SERVER_IP, SERVER_PORT) != OK:
		_on_connection_failed()
		return
		
	multiplayer.multiplayer_peer = client_peer
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(peer_id):
	if get_player_count() >= MAX_PLAYERS:
		print("Player limit reached.")
		return
		
	if multiplayer.is_server():
		# Spawn the new player for everyone
		spawn_player.rpc(peer_id)
		
		# Spawn all existing players for the new player
		for id in connected_players:
			spawn_player.rpc_id(peer_id, id)

		# Add to the list of known players
		connected_players.append(peer_id)

@rpc("call_local", "reliable")
func spawn_player(id: int):
	add_player_to_game(id)

func add_player_to_game(id: int):
	if current_multiplayer_spawner.has_node(str(id)):
		print("Player %s already exists!" % id)
		return

	print("Player %s joined the game!" % id)
	var spawn_index = 0
	if id == 1:
		spawn_index = 0  # Host
	else:
		spawn_index = 1  # Client (or next peer)
		
	var player = PLAYER.instantiate()
	
	player.player_id = id
	player.name = str(id)

	player.global_position = current_spawn_points.get_child(spawn_index).global_position
	player.set_multiplayer_authority(id)

	players.append(player)
	current_multiplayer_spawner.add_child(player)
		
func _del_player(id: int):
	print("Player %s left the game!" % id)
	if not current_multiplayer_spawner.has_node(str(id)):
		return
	current_multiplayer_spawner.get_node(str(id)).queue_free()
	
func get_player_count():
	return players.size()
	
func _on_peer_disconnected(peer_id):
	connected_players.erase(peer_id)
	_del_player(peer_id)
	
	var hud := get_tree().root.get_node_or_null("Game/GameUI/HUD")
	if not hud:
		return

	if multiplayer.is_server():
		client_disconnected.emit(peer_id)
		if hud.has_method("on_player_disconnected"):
			hud.on_player_disconnected.call_deferred(peer_id)
	elif peer_id == 1:  # Host disconnected
		host_disconnected.emit()
		if hud.has_method("on_host_disconnected"):
			hud.on_host_disconnected.call_deferred()
	
func _on_connection_failed() -> void:
	reset_multiplayer_state()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_server_disconnected() -> void:
	reset_multiplayer_state()
	host_disconnected.emit()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func reset_multiplayer_state() -> void:
	multiplayer_mode_enabled = false
	host_mode_enabled = false
	players.clear()
	connected_players.clear()
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	multiplayer_mode_enabled = false
	host_mode_enabled = false
	players.clear()
	connected_players.clear()
	
		# 🆕 Show the MenuPanel again
	var menu_panel := get_tree().root.get_node_or_null("Game/GameUI/HUD/MenuPanel")
	if menu_panel:
		menu_panel.visible = true
		
	# 🆕 Optionally reset other game UI too if needed
	var hud := get_tree().root.get_node_or_null("Game/GameUI/HUD")
	if hud:
		if hud.has_node("Winner"):
			hud.get_node("Winner").text = ""
		if hud.has_node("ChoiceLabel"):
			hud.get_node("ChoiceLabel").text = ""
			
			
func terminate_host_session():
	print("Terminating Host Session...")
	
	# Notify clients that host is shutting down
	if multiplayer.is_server():
		announce_server_shutdown.rpc() # <=== see step 2 below
	
	# Clean up server
	reset_multiplayer_state()
	
@rpc("call_local", "reliable")
func announce_server_shutdown():
	print("Server has shut down.")
	reset_multiplayer_state()
