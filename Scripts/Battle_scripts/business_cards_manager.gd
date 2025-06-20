extends Node2D
class_name BusinessCardsManager

var placed_businesses: Dictionary = {} # hex_position -> Card
var hex_grid_ref: TileMapLayer
var economy_manager: EconomyManager

signal business_placed(card: Card, position: Vector2i)
signal business_income_generated(card: Card, income: int)

func _ready():
	economy_manager = get_node_or_null("../../Economy_manager")
	hex_grid_ref = get_node_or_null("../../Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer")

func place_business(card: Card, hex_pos: Vector2i, player: int) -> bool:
	if hex_pos in placed_businesses:
		print("Location already has a business!")
		return false
	
	# Place the business
	placed_businesses[hex_pos] = card
	card.global_position = hex_grid_ref.map_to_local(hex_pos)
	
	# Change card state
	if card.state_manager:
		card.state_manager.change_state("played")
	
	# Apply business effects (income boost, special abilities, etc.)
	_apply_business_effects(card, player)
	
	business_placed.emit(card, hex_pos)
	return true

func _apply_business_effects(card: Card, player: int):
	# This would depend on your specific card effects
	# Example: if card has income property
	if card.has_method("get_income_boost"):
		var income_boost = card.get_income_boost()
		if economy_manager:
			economy_manager.add_income_source(player, income_boost)

func get_business_at_location(hex_pos: Vector2i) -> Card:
	return placed_businesses.get(hex_pos, null)

func get_total_businesses(player: int) -> int:
	var count = 0
	for card in placed_businesses.values():
		if card.get_meta("owner", 0) == player:
			count += 1
	return count
