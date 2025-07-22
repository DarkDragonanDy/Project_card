# FieldSyncManager.gd
extends Node
class_name FieldSyncManager

# Система синхронизации игрового поля между клиентами

# Ссылки на игровые системы
@onready var hex_grid: TileMapLayer
@onready var game_manager: GameManager

# Синхронизированное состояние поля
var synced_cards: Dictionary[Vector2i, Dictionary] = {}  # позиция -> данные карты
var cards_on_field: Dictionary[Vector2i, Card] = {}     # позиция -> экземпляр карты

func _ready():
	# Находим необходимые ноды
	_find_game_nodes()
	
	# Подключаемся к сетевым событиям
	NetworkManager.game_action_received.connect(_on_field_sync_action)

func _find_game_nodes():
	# Ищем hex_grid в сцене
	hex_grid = get_node_or_null("../Control_lair/Game_UI/GridContainer/Game_board/TileMapLayer")
	if not hex_grid:
		print("Warning: HexGrid not found for field sync!")
	
	# Ищем game_manager
	game_manager = get_node_or_null("../Game_manager")
	if not game_manager:
		print("Warning: GameManager not found for field sync!")

# ================== СЕРВЕРНАЯ ЧАСТЬ ==================

func sync_card_placement(card_name: String, hex_position: Vector2i, player_name: String):
	"""Сервер создает данные карты и синхронизирует с клиентами"""
	
	if not NetworkMode.is_server():
		return
	
	print("Server syncing card placement: ", card_name, " at ", hex_position)
	
	# Создаем данные карты для синхронизации
	var card_data = _create_sync_data(card_name, hex_position, player_name)
	
	# Сохраняем на сервере
	synced_cards[hex_position] = card_data
	
	# Отправляем всем клиентам
	NetworkManager._broadcast_action_result.rpc({
		"type": "field_card_placed",
		"data": card_data
	})
	
	print("Card synced to all clients: ", card_name)

func _create_sync_data(card_name: String, hex_position: Vector2i, player_name: String) -> Dictionary:
	"""Создает данные карты для синхронизации"""
	
	# Получаем базовую информацию о карте из базы данных
	var base_card = CardDatabase.create_card_instance(card_name)
	if not base_card:
		print("Error: Cannot create card for sync: ", card_name)
		return {}
	
	var sync_data = {
		"card_name": base_card.card_name,
		"card_description": base_card.card_description,
		"card_cost": base_card.card_cost,
		"hex_position": {"x": hex_position.x, "y": hex_position.y},
		"owner": player_name,
		"placed_turn": NetworkManager.game_state.get("current_turn", 1),
		"unique_id": _generate_card_id(card_name, hex_position, player_name)
	}
	
	# Освобождаем временную карту
	base_card.queue_free()
	
	return sync_data

func _generate_card_id(card_name: String, hex_pos: Vector2i, player: String) -> String:
	"""Генерирует уникальный ID карты"""
	var timestamp = Time.get_unix_time_from_system()
	return "%s_%s_%d_%d_%d" % [card_name, player, hex_pos.x, hex_pos.y, timestamp]

# ================== КЛИЕНТСКАЯ ЧАСТЬ ==================

func _on_field_sync_action(action_data: Dictionary):
	"""Обрабатывает синхронизацию поля"""
	
	match action_data.type:
		"field_card_placed":
			_place_synced_card(action_data.data)
		"field_state_sync":
			_sync_full_field(action_data.data)

func _place_synced_card(card_data: Dictionary):
	"""Размещает карту на поле по данным от сервера"""
	
	var hex_pos = Vector2i(card_data.hex_position.x, card_data.hex_position.y)
	
	print("Placing synced card: ", card_data.card_name, " at ", hex_pos)
	
	# Создаем визуальную карту
	var card = await _create_field_card(card_data)
	if not card:
		print("Failed to create synced card")
		return
	
	# Позиционируем карту на поле
	_position_card_on_field(card, hex_pos)
	
	# Сохраняем данные
	synced_cards[hex_pos] = card_data
	cards_on_field[hex_pos] = card
	
	print("Synced card placed successfully: ", card_data.card_name)

func _create_field_card(card_data: Dictionary) -> Card:
	"""Создает экземпляр карты из синхронизированных данных"""
	
	var card = CardDatabase.create_card_instance(card_data.card_name)
	if not card:
		return null
	
	# Применяем синхронизированные данные
	card.card_unique_id = card_data.unique_id
	card.card_name = card_data.card_name
	card.card_description = card_data.card_description
	card.card_cost = card_data.card_cost
	
	# Настраиваем карту для поля
	_setup_field_card(card, card_data)
	
	# Добавляем в сцену
	get_tree().current_scene.add_child(card)
	
	return card

func _setup_field_card(card: Card, card_data: Dictionary):
	"""Настраивает карту для размещения на поле"""
	
	# Отключаем перетаскивание (карта уже размещена)
	if card.drag_handler:
		card.drag_handler.set_draggable(false)
	
	# Устанавливаем состояние "на поле"
	if card.state_manager:
		card.state_manager.change_state("played")
	
	# Уменьшаем размер для поля
	card.scale = Vector2(0.7, 0.7)
	
	# Сохраняем метаданные
	card.set_meta("owner", card_data.owner)
	card.set_meta("placed_turn", card_data.placed_turn)
	card.set_meta("is_synced", true)

func _position_card_on_field(card: Card, hex_position: Vector2i):
	"""Позиционирует карту на указанной hex позиции"""
	
	if not hex_grid:
		print("Cannot position card - hex_grid not found")
		return
	
	# Конвертируем hex координаты в мировые
	var world_pos = hex_grid.map_to_local(hex_position)
	card.global_position = hex_grid.to_global(world_pos)
	
	print("Card positioned at world pos: ", card.global_position)

func _sync_full_field(field_data: Dictionary):
	"""Синхронизирует полное состояние поля (для новых игроков)"""
	
	print("Syncing full field state")
	
	# Очищаем текущие карты
	_clear_field()
	
	# Размещаем все карты из данных
	var cards_data = field_data.get("cards", {})
	for pos_key in cards_data.keys():
		var card_data = cards_data[pos_key]
		await _place_synced_card(card_data)

func _clear_field():
	"""Очищает поле от всех карт"""
	
	for card in cards_on_field.values():
		if is_instance_valid(card):
			card.queue_free()
	
	cards_on_field.clear()
	synced_cards.clear()

# ================== УТИЛИТЫ ==================

func is_position_occupied(hex_pos: Vector2i) -> bool:
	"""Проверяет, занята ли позиция"""
	return hex_pos in synced_cards

func get_card_at_position(hex_pos: Vector2i) -> Card:
	"""Возвращает карту на указанной позиции"""
	return cards_on_field.get(hex_pos, null)

func get_sync_data_at_position(hex_pos: Vector2i) -> Dictionary:
	"""Возвращает данные синхронизации карты"""
	return synced_cards.get(hex_pos, {})

func get_field_state() -> Dictionary:
	"""Возвращает полное состояние поля для синхронизации"""
	return {"cards": synced_cards.duplicate()}

# ================== DEBUG ==================

func print_field_state():
	print("=== Field Sync State ===")
	print("Cards on field: ", cards_on_field.size())
	for hex_pos in synced_cards.keys():
		var card_data = synced_cards[hex_pos]
		print("  ", hex_pos, ": ", card_data.card_name, " (", card_data.owner, ")")

func _input(event):
	# Debug: нажмите F1 для вывода состояния поля
	if event.is_action_pressed("ui_home"):
		print_field_state()
