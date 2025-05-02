extends Area2D
signal game_over(winner_id)

func _on_body_entered(body):
	if MultiplayerManager.multiplayer_mode_enabled && multiplayer.get_unique_id() == body.player_id:
		print("Player %s WINS!" % multiplayer.get_unique_id())
		emit_signal("game_over", multiplayer.get_unique_id())
