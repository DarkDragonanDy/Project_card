# login_screen.gd
# login_screen.gd
extends Control

@onready var login_input: LineEdit = $VBoxContainer/ColorRect_Start_game/Name_space
@onready var password_input: LineEdit = $VBoxContainer/ColorRect_Start_game2/Password_space
@onready var login_button: Button = $VBoxContainer/ColorRect_Collection/Login_button





#
func _on_login_pressed() -> void:
	var login = login_input.text
	var password = password_input.text
	
	if PlayerDatabase.verify_login(login, password):
		PlayerDatabase.current_user = login
		
		
		# Загружаем колоду пользователя
		DeckData.load_user_deck()
		
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://Scenes/node_scene.tscn")

		
	
	
