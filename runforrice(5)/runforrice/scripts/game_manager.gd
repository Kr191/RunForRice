extends Node

func host_pressed():
	print("host pressed")
	%GameUI.get_node("HUD").hide()
	MultiplayerManager.become_host()
	
func join_pressed():
	print("join pressed")
	%GameUI.get_node("HUD").hide()
	MultiplayerManager.join_as_player_2()
