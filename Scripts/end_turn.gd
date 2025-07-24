extends Button
func _ready():
	pressed.connect(_on_end_turn_pressed)

func _on_end_turn_pressed():
	print("End turn button pressed")
	NetworkManager.send_game_action("request_end_turn", {})
