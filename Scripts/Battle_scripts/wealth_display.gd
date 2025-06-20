extends Control
@onready var economy_manager: EconomyManager = $"../../../Economy_manager"
@onready var income_label_player: Label = $"Player_wealth_display/Player_income"
@onready var wealth_label_player: Label = $"Player_wealth_display/Player_wealth"
@onready var income_label_opponent: Label = $"Opponent_wealth_display/Player_income"
@onready var wealth_label_opponent: Label = $"Opponent_wealth_display/Player_wealth"

func _ready():
	
	connect_signals()
	wealth_changed_text(1,economy_manager.get_wealth(1))
	income_changed_text(1,economy_manager.get_income(1))
	wealth_changed_text(2,economy_manager.get_wealth(2))
	income_changed_text(1,economy_manager.get_income(2))
	
func connect_signals():
	if economy_manager:
		if economy_manager.has_signal("wealth_changed"):
			economy_manager.wealth_changed.connect(wealth_changed_text)
		if economy_manager.has_signal("income_changed"):
			economy_manager.income_changed.connect(income_changed_text)
			
func wealth_changed_text(player: int, wealth: int):
	if player==1:
		wealth_label_player.text=str(wealth)
	else:
		wealth_label_opponent.text=str(wealth)
func income_changed_text(player: int, income: int):
	if player==1:
		income_label_player.text=str(income)
	else:
		income_label_opponent.text=str(income)

	
