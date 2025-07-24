extends Node
class_name ServerCardValidator

var game_state_manager: ServerGameState


func _ready():
	game_state_manager = NetworkManager.server_game_state

func validate_card_play(player_id: String, card_name: String, hex_position: Vector2i) -> Dictionary:
	# Получаем данные карты из существующей базы
	print("Validating card play for ", player_id, " - card: ", card_name)
	var card_instance = CardDatabase.create_card_instance(card_name)
	if not card_instance:
		return {"valid": false, "reason": "unknown_card"}
	
	# Проверка стоимости
	var player_wealth = game_state_manager.get_player_wealth(player_id)
	if player_wealth < card_instance.card_cost:
		card_instance.queue_free()
		return {"valid": false, "reason": "insufficient_funds"}
	
	# Проверка занятости клетки
	if game_state_manager.is_hex_occupied(hex_position):
		card_instance.queue_free()
		return {"valid": false, "reason": "hex_occupied"}
	
	# Валидация успешна - обновляем состояние
	game_state_manager.spend_player_wealth(player_id, card_instance.card_cost)
	game_state_manager.place_card_on_board(player_id, card_name, hex_position)
	
	var result = {
		"valid": true,
		"new_wealth": game_state_manager.get_player_wealth(player_id),
		"card_cost": card_instance.card_cost
	}
	
	print("Card approved! New wealth: ", game_state_manager.get_player_wealth(player_id), " (spent ", card_instance.card_cost, ")")
	
	card_instance.queue_free()
	return result
