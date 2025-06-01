extends Node2D
class_name Card


@export var card_name: String = ""
@export var card_description: String = ""
@export var card_cost: int = 0
@export var card_unique_id: String = ""
@export var card_art: Texture2D = null # 


@onready var card_back: Sprite2D = $Card_back
@onready var text_box = $Card_box_text/Card_text_box
@onready var cost_box = $Card_box_cost/Card_text_cost
@onready var art = $Card_art
@onready var name_label = $Card_box_name/Card_text_name

func _init(name: String = "", desc: String = "", cost: int = 0, id: String = ""):
	card_name = name
	card_description = desc
	card_cost = cost
	card_unique_id = id

func update_card_display():
	if name_label:
		name_label.text = card_name
	if text_box:
		text_box.text = card_description
	if cost_box:
		cost_box.text = str(card_cost)
	if art:
		art.texture=card_art;

func card_effect():
	pass
	
func _ready():
	update_card_display()

#func clone() -> Card:
	#var new_card = Card.new()
	#new_card.card_name = card_name
	#new_card.card_description = card_description
	#new_card.card_cost = card_cost
	#new_card.card_unique_id = card_unique_id
	#return new_card
