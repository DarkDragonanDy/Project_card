extends Node


# Клиент хранит только то, что ему разрешил сервер
var my_wealth: int = 0
var my_income: int = 0
var my_hand_size: int = 0
var opponent_wealth: int = 0
var opponent_income: int = 0
var current_turn: int = 1
var current_player: int = 1

signal state_updated(update_type: String)

func update_from_server(update_data: Dictionary):
	match update_data.get("type", ""):
		"wealth_update":
			my_wealth = update_data.get("wealth", my_wealth)
			state_updated.emit("wealth")
		"income_update":
			my_income = update_data.get("income", my_income)
			state_updated.emit("income")
		"opponent_update":
			opponent_wealth = update_data.get("wealth", opponent_wealth)
			opponent_income = update_data.get("income", opponent_income)
			state_updated.emit("opponent")
		"turn_update":
			current_turn = update_data.get("turn", current_turn)
			current_player = update_data.get("player", current_player)
			state_updated.emit("turn")
