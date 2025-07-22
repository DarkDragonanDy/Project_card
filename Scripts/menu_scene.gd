extends Control


func _on_start_game_pressed() -> void:
	_show_lobby()
	
func _on_playground_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/playground.tscn")
func _on_collection_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/collection.tscn")

func _show_lobby():
	# Создаем лобби
	var lobby_script = load("res://Scripts/Server/SimpleLobbyManager.gd")
	var lobby = lobby_script.new()
	get_tree().current_scene.add_child(lobby)
	lobby.start_game.connect(_transition_to_game)
func _transition_to_game():
	print("Transitioning to game scene...")
	get_tree().change_scene_to_file("res://Scenes/batle_scene.tscn")
