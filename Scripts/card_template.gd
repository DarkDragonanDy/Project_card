extends Node2D
class_name Card


@export var card_name: String = ""
@export var card_description: String = ""
@export var card_cost: int = 0
@export var card_unique_id: String = "" # Optional, could be used for reference

func _init
(
	name: String = "",
	desc: String = "",
	cost: int = 0,
	card_type: String = "Generic",
	attack: int = 0,
	health: int = 0,
	id: String = ""
):
		
		card_name = name
		card_description = desc
		card_cost = cost
		card_unique_id = id



func clone() -> Card:
	var new_card = Card.new()
	new_card.card_name = card_name
	new_card.card_description = card_description
	new_card.card_cost = card_cost
	new_card.card_unique_id = card_unique_id
	return new_card
