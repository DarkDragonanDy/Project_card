extends Control


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/battle.tscn")
func _on_playground_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/playground.tscn")
