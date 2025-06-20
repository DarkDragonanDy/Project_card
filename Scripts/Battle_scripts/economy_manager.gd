extends Node
class_name EconomyManager

signal wealth_changed(player: int, new_wealth: int)
signal income_changed(player: int, new_income: int)
signal turn_income_calculated(player: int, income_amount: int)

var player_wealth: Array[int] = [1000, 1000]  # Starting wealth
var player_income: Array[int] = [100, 100]    # Income per turn
var max_turns: int = 10
var wealth_history: Array[Array] = [[], []]    # Track wealth over time

func spend_wealth(player: int, amount: int) -> bool:
	if player_wealth[player - 1] >= amount:
		player_wealth[player - 1] -= amount
		wealth_changed.emit(player, player_wealth[player - 1])
		return true
	return false

func add_income_source(player: int, income_boost: int):
	player_income[player - 1] += income_boost
	income_changed.emit(player, player_income[player - 1])

func process_turn_income(player: int):
	var income = player_income[player - 1]
	player_wealth[player - 1] += income
	wealth_history[player - 1].append(player_wealth[player - 1])
	
	turn_income_calculated.emit(player, income)
	wealth_changed.emit(player, player_wealth[player - 1])

func get_wealth(player: int) -> int:
	
	return player_wealth[player - 1]

func get_income(player: int) -> int:
	return player_income[player - 1]

func get_wealth_difference() -> int:
	return player_wealth[0] - player_wealth[1]

func determine_winner() -> int:
	if player_wealth[0] > player_wealth[1]:
		return 1
	elif player_wealth[1] > player_wealth[0]:
		return 2
	return 0  # Tie
