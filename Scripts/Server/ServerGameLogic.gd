# ServerGameLogic.gd - Серверная логика БЕЗ UI
extends Node
class_name ServerGameLogic

# Серверное состояние игры (замена всех ваших менеджеров)
var game_state: SharedGameData.GameState
var card_database: Dictionary = {}

# Состояние сервера
var is_game_active: bool = false
var connected_players: Array[String] = []

# Консольные логи (если сервер запущен с консолью)
var server_console_log: TextEdit
var enable_console_logging: bool = false

signal game_started
signal game_ended(winner: String)
signal turn_changed(new_player: String, turn_number: int)
signal server_log(message: String)

func _ready():
	# Инициализируем только если это сервер
	if not NetworkMode.is_server():
		queue_free()
		return
	
	_log_to_console("=== STARTING SERVER GAME LOGIC ===")
	
	# Создаем игровое состояние
	game_state = SharedGameData.GameState.new()
	
	# Загружаем базу карт
	_load_card_database()
	
	# Подключаемся к NetworkManager (не напрямую к сетевым событиям)
	_connect_to_network_manager()
	
	# Пытаемся найти консоль сервера для логирования
	_setup_console_logging()
	
	_log_to_console("Server game logic initialized and ready for players")

func _connect_to_network_manager():
	"""Подключается к NetworkManager для получения событий"""
	# Подключаемся к событиям через NetworkManager
	if NetworkManager.has_signal("player_connected"):
		NetworkManager.player_connected.connect(_on_player_connected)
	if NetworkManager.has_signal("player_disconnected"):
		NetworkManager.player_disconnected.connect(_on_player_disconnected)
	
	# Подключаем сигнал для логов
	server_log.connect(_on_server_log_message)
	
	_log_to_console("Connected to NetworkManager events")

func _setup_console_logging():
	"""Настраивает логирование в консоль сервера"""
	# Ищем консоль сервера (если она есть)
	server_console_log = get_node_or_null("/root/*/ServerTerminal/ServerLog")
	
	if server_console_log:
		enable_console_logging = true
		_log_to_console("Console logging enabled")
	else:
		enable_console_logging = false
		print("No server console found - using print() for logs")

func _log_to_console(message: String):
	"""Логирует сообщение в консоль сервера или print"""
	var timestamp = Time.get_datetime_string_from_system()
	var full_message = "[" + timestamp + "] " + message
	
	# Всегда выводим в обычный лог
	print(full_message)
	
	# Если есть консоль - добавляем туда
	if enable_console_logging and is_instance_valid(server_console_log):
		server_console_log.text += full_message + "\n"
		
		# Автоскролл
		await get_tree().process_frame
		server_console_log.scroll_vertical = server_console_log.get_line_count()
	
	# Испускаем сигнал для других систем
	server_log.emit(full_message)

func _on_server_log_message(message: String):
	"""Обработчик для внешних сигналов логирования"""
	# Можно добавить дополнительную обработку логов
	pass

func _load_card_database():
	"""Загружает данные всех карт"""
	card_database = {
		"Meadow": SharedGameData.CardData.new("Meadow", "Increases income by 50", 150),
		"iceball": SharedGameData.CardData.new("iceball", "Attack spell", 100),
		"Fishing Place": SharedGameData.CardData.new("Fishing Place", "Increases income by 30", 200)
	}
	
	_log_to_console("📋 Loaded " + str(card_database.size()) + " cards into database")

func _process_player_request(action_data: Dictionary):
	"""Главный обработчик всех запросов от игроков"""
	var player_name = action_data.get("player_id", "Unknown")
	_log_to_console("📡 Processing request: " + action_data.type + " from " + player_name)
	
	match action_data.type:
		"request_start_game":
			_handle_start_game_request(action_data)
		"request_card_play":
			_handle_card_play_request(action_data)
		"request_end_turn":
			_handle_end_turn_request(action_data)
		"request_game_state":
			_send_full_game_state_to_player(action_data.get("sender_peer_id", 0))
		_:
			_log_to_console("⚠ Unknown request type: " + action_data.type)

# ===== УПРАВЛЕНИЕ ИГРОЙ =====

func _handle_start_game_request(action_data: Dictionary):
	"""Начинает новую игру"""
	if is_game_active:
		_log_to_console("⚠ Game start requested but game already active")
		return
	
	# Получаем список подключенных игроков из NetworkManager
	if NetworkManager.has_method("get_connected_players"):
		connected_players = NetworkManager.get_connected_players()
	else:
		# Fallback - получаем из lobby_players
		connected_players = NetworkManager.lobby_players.keys()
	
	if connected_players.size() < 2:
		_log_to_console("⚠ Cannot start game - only " + str(connected_players.size()) + " players connected")
		return
	
	_log_to_console("🎮 Starting game with players: " + str(connected_players))
	
	# Инициализируем игроков
	_initialize_players()
	
	# Настраиваем начальное состояние
	game_state.current_player = connected_players[0]
	game_state.current_turn = 1
	game_state.game_phase = "playing"
	is_game_active = true
	
	# Отправляем всем игрокам состояние игры
	_broadcast_game_state()
	
	# Отправляем каждому игроку его руку
	_send_hands_to_players()
	
	game_started.emit()
	_log_to_console("✅ Game started successfully - Turn 1, Player: " + game_state.current_player)

func _initialize_players():
	"""Инициализирует данные всех игроков"""
	for player_name in connected_players:
		var player_data = SharedGameData.PlayerData.new()
		player_data.name = player_name
		player_data.wealth = 1000
		player_data.income = 100
		
		# Создаем стартовую колоду (упрощенно)
		var starting_deck = ["Meadow", "iceball", "Fishing Place", "Meadow", "iceball", "Fishing Place"]
		
		# Даем стартовые карты в руку
		for i in range(4):
			if i < starting_deck.size():
				player_data.hand.append(starting_deck[i])
		
		# Остальные карты в колоду
		for i in range(4, starting_deck.size()):
			player_data.deck.append(starting_deck[i])
		
		game_state.players[player_name] = player_data
		_log_to_console("👤 Initialized player: " + player_name + " (Hand: " + str(player_data.hand.size()) + " cards, Wealth: $" + str(player_data.wealth) + ")")

# ===== ОБРАБОТКА КАРТ =====

func _handle_card_play_request(action_data: Dictionary):
	"""Обрабатывает запрос на размещение карты"""
	var player_name = action_data.player_id
	var card_name = action_data.data.card_name
	var hex_pos = Vector2i(action_data.data.hex_position.x, action_data.data.hex_position.y)
	
	_log_to_console("🎯 Card play request: " + card_name + " by " + player_name + " at (" + str(hex_pos.x) + "," + str(hex_pos.y) + ")")
	
	# Валидация
	var validation_result = _validate_card_play(player_name, card_name, hex_pos)
	if not validation_result.success:
		_log_to_console("❌ Card play rejected: " + validation_result.message)
		_send_error_to_player(action_data.get("sender_peer_id", 0), validation_result.message)
		return
	
	# Применяем действие
	var play_result = _execute_card_play(player_name, card_name, hex_pos)
	if play_result.success:
		# Отправляем обновление всем игрокам
		_broadcast_game_state()
		_send_success_to_player(action_data.get("sender_peer_id", 0), "Card played successfully")
		_log_to_console("✅ Card play successful: " + card_name + " placed at (" + str(hex_pos.x) + "," + str(hex_pos.y) + ")")
	else:
		_log_to_console("❌ Card play execution failed: " + play_result.message)
		_send_error_to_player(action_data.get("sender_peer_id", 0), play_result.message)

func _validate_card_play(player_name: String, card_name: String, hex_pos: Vector2i) -> SharedGameData.ActionResult:
	"""Валидирует размещение карты"""
	
	# Проверяем очередь игрока
	if game_state.current_player != player_name:
		return SharedGameData.ActionResult.new(false, "Not your turn")
	
	# Проверяем игрока
	var player_data = game_state.get_player_data(player_name)
	if not player_data:
		return SharedGameData.ActionResult.new(false, "Player not found")
	
	# Проверяем карту в руке
	if not player_data.has_card_in_hand(card_name):
		return SharedGameData.ActionResult.new(false, "Card not in hand")
	
	# Проверяем позицию
	if game_state.is_position_occupied(hex_pos):
		return SharedGameData.ActionResult.new(false, "Position already occupied")
	
	# Проверяем стоимость
	var card_data = card_database.get(card_name)
	if not card_data:
		return SharedGameData.ActionResult.new(false, "Invalid card")
	
	if not player_data.can_afford(card_data.cost):
		return SharedGameData.ActionResult.new(false, "Not enough wealth")
	
	return SharedGameData.ActionResult.new(true, "Valid play")

func _execute_card_play(player_name: String, card_name: String, hex_pos: Vector2i) -> SharedGameData.ActionResult:
	"""Выполняет размещение карты"""
	var player_data = game_state.get_player_data(player_name)
	var card_data = card_database.get(card_name)
	
	# Сохраняем данные для логирования
	var old_wealth = player_data.wealth
	var old_income = player_data.income
	
	# Убираем карту из руки
	player_data.remove_card_from_hand(card_name)
	
	# Списываем деньги
	player_data.spend_wealth(card_data.cost)
	
	# Размещаем на поле
	var field_card = SharedGameData.FieldCard.new(card_name, player_name, hex_pos, game_state.current_turn)
	var pos_key = str(hex_pos.x) + "," + str(hex_pos.y)
	game_state.field[pos_key] = field_card
	
	# Применяем эффекты карты
	card_data.apply_effects(game_state, player_name, hex_pos)
	
	# Логируем изменения
	var wealth_change = player_data.wealth - old_wealth
	var income_change = player_data.income - old_income
	
	_log_to_console("💰 " + player_name + " wealth: $" + str(old_wealth) + " → $" + str(player_data.wealth) + " (" + str(wealth_change) + ")")
	if income_change != 0:
		_log_to_console("📈 " + player_name + " income: +" + str(old_income) + " → +" + str(player_data.income) + " (" + str(income_change) + ")")
	
	return SharedGameData.ActionResult.new(true, "Card played")

# ===== УПРАВЛЕНИЕ ХОДАМИ =====

func _handle_end_turn_request(action_data: Dictionary):
	"""Обрабатывает окончание хода"""
	var player_name = action_data.player_id
	
	if game_state.current_player != player_name:
		_send_error_to_player(action_data.sender_peer_id, "Not your turn")
		return
	
	_execute_end_turn()

func _execute_end_turn():
	"""Выполняет окончание хода"""
	_log_to_console("⏭ Ending turn for player: " + game_state.current_player)
	
	# Применяем доходы
	_apply_turn_income()
	
	# Переключаем игрока
	_switch_to_next_player()
	
	# Проверяем условия окончания игры
	if _check_game_end_conditions():
		_end_game()
		return
	
	# Отправляем обновление
	_broadcast_game_state()
	
	turn_changed.emit(game_state.current_player, game_state.current_turn)

func _apply_turn_income():
	"""Начисляет доход всем игрокам"""
	_log_to_console("💵 Applying turn income to all players:")
	
	for player_name in game_state.players.keys():
		var player_data = game_state.players[player_name]
		var old_wealth = player_data.wealth
		player_data.wealth += player_data.income
		
		_log_to_console("  💰 " + player_name + ": $" + str(old_wealth) + " + $" + str(player_data.income) + " = $" + str(player_data.wealth))

func _switch_to_next_player():
	"""Переключает на следующего игрока"""
	var current_index = connected_players.find(game_state.current_player)
	var next_index = (current_index + 1) % connected_players.size()
	
	var old_player = game_state.current_player
	game_state.current_player = connected_players[next_index]
	
	# Если дошли до первого игрока - увеличиваем номер хода
	if next_index == 0:
		game_state.current_turn += 1
		_log_to_console("🔄 Turn " + str(game_state.current_turn) + " started")
	
	_log_to_console("👤 Player change: " + old_player + " → " + game_state.current_player)

# ===== СЕТЕВОЕ ВЗАИМОДЕЙСТВИЕ =====

func _broadcast_game_state():
	"""Отправляет текущее состояние игры всем игрокам"""
	var state_data = _prepare_public_game_state()
	
	NetworkManager._broadcast_action_result.rpc({
		"type": "game_state_update",
		"data": state_data
	})
	
	print("Game state broadcasted to all players")

func _prepare_public_game_state() -> Dictionary:
	"""Готовит публичное состояние игры (без приватной информации)"""
	var public_state = {
		"players": {},
		"field": {},
		"turn_info": {
			"current_player": game_state.current_player,
			"current_turn": game_state.current_turn,
			"game_phase": game_state.game_phase
		}
	}
	
	# Публичная информация об игроках
	for player_name in game_state.players.keys():
		var player_data = game_state.players[player_name]
		public_state.players[player_name] = {
			"name": player_data.name,
			"wealth": player_data.wealth,
			"income": player_data.income,
			"hand_size": player_data.hand.size(),
			"deck_size": player_data.deck.size()
		}
	
	# Информация о поле
	for pos_key in game_state.field.keys():
		var field_card = game_state.field[pos_key]
		public_state.field[pos_key] = {
			"card_name": field_card.card_name,
			"owner": field_card.owner,
			"hex_position": {"x": field_card.hex_position.x, "y": field_card.hex_position.y},
			"placed_turn": field_card.placed_turn
		}
	
	return public_state

func _send_hands_to_players():
	"""Отправляет каждому игроку его руку (приватно)"""
	for player_name in game_state.players.keys():
		var player_data = game_state.players[player_name]
		var peer_id = _get_peer_id_for_player(player_name)
		
		if peer_id > 0:
			NetworkManager._send_private_data.rpc_id(peer_id, {
				"type": "player_hand_update",
				"data": {
					"hand": player_data.hand.duplicate(),
					"deck_size": player_data.deck.size()
				}
			})

func _get_peer_id_for_player(player_name: String) -> int:
	"""Получает peer_id игрока по имени"""
	# Эта функция должна быть реализована в NetworkManager
	return NetworkManager.get_peer_id_for_player(player_name)

func _send_error_to_player(peer_id: int, message: String):
	"""Отправляет сообщение об ошибке конкретному игроку"""
	NetworkManager._send_private_data.rpc_id(peer_id, {
		"type": "error_message",
		"data": {"message": message}
	})

func _send_success_to_player(peer_id: int, message: String):
	"""Отправляет сообщение об успехе конкретному игроку"""
	NetworkManager._send_private_data.rpc_id(peer_id, {
		"type": "success_message",
		"data": {"message": message}
	})

# ===== ОКОНЧАНИЕ ИГРЫ =====

func _check_game_end_conditions() -> bool:
	"""Проверяет условия окончания игры"""
	return game_state.current_turn > game_state.max_turns

func _end_game():
	"""Завершает игру"""
	var winner = _determine_winner()
	is_game_active = false
	
	_log_to_console("🏆 GAME ENDED!")
	_log_to_console("🥇 Winner: " + winner)
	
	# Логируем финальные результаты
	_log_final_results()
	
	NetworkManager._broadcast_action_result.rpc({
		"type": "game_ended",
		"data": {"winner": winner}
	})
	
	game_ended.emit(winner)

func _log_final_results():
	"""Логирует финальные результаты игры"""
	_log_to_console("📊 FINAL RESULTS:")
	
	var sorted_players = []
	for player_name in game_state.players.keys():
		var player_data = game_state.players[player_name]
		sorted_players.append({
			"name": player_name,
			"wealth": player_data.wealth,
			"income": player_data.income
		})
	
	# Сортируем по богатству
	sorted_players.sort_custom(func(a, b): return a.wealth > b.wealth)
	
	for i in range(sorted_players.size()):
		var player = sorted_players[i]
		var position = str(i + 1)
		var medal = "🥇" if i == 0 else ("🥈" if i == 1 else "🥉")
		_log_to_console("  " + medal + " " + position + ". " + player.name + " - $" + str(player.wealth) + " (Income: +$" + str(player.income) + "/turn)")

func _determine_winner() -> String:
	"""Определяет победителя"""
	var highest_wealth = 0
	var winner = ""
	
	for player_name in game_state.players.keys():
		var player_data = game_state.players[player_name]
		if player_data.wealth > highest_wealth:
			highest_wealth = player_data.wealth
			winner = player_name
	
	return winner

# ===== ОБРАБОТЧИКИ СОБЫТИЙ =====

func _on_player_connected(player_name: String):
	"""Обрабатывает подключение игрока"""
	_log_to_console("→ Player connected: " + player_name)

func _on_player_disconnected(player_name: String):
	"""Обрабатывает отключение игрока"""
	_log_to_console("← Player disconnected: " + player_name)
	
	if is_game_active:
		_log_to_console("⚠ Game paused due to player disconnect")
		# Можно приостановить игру или продолжить с AI

# ===== ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ =====

func _send_full_game_state_to_player(peer_id: int):
	"""Отправляет полное состояние игры конкретному игроку"""
	if peer_id <= 0:
		return
		
	var state_data = _prepare_public_game_state()
	
	NetworkManager._send_private_data.rpc_id(peer_id, {
		"type": "full_game_state",
		"data": state_data
	})
	
	_log_to_console("📋 Full game state sent to peer " + str(peer_id))

# ===== УТИЛИТЫ =====

func get_game_state() -> SharedGameData.GameState:
	"""Возвращает текущее состояние игры"""
	return game_state

func is_player_turn(player_name: String) -> bool:
	"""Проверяет, ход ли указанного игрока"""
	return game_state.current_player == player_name

func get_player_hand(player_name: String) -> Array[String]:
	"""Возвращает руку игрока"""
	var player_data = game_state.get_player_data(player_name)
	return player_data.hand if player_data else []

func get_game_statistics() -> Dictionary:
	"""Возвращает статистику игры для консоли"""
	return {
		"is_active": is_game_active,
		"current_turn": game_state.current_turn if game_state else 0,
		"current_player": game_state.current_player if game_state else "",
		"players_count": connected_players.size(),
		"cards_on_field": game_state.field.size() if game_state else 0
	}

# ===== DEBUG И МОНИТОРИНГ =====

func print_game_status():
	"""Выводит текущий статус игры в консоль"""
	if not is_game_active:
		_log_to_console("🔴 Game is not active")
		return
	
	_log_to_console("🟢 GAME STATUS:")
	_log_to_console("  Turn: " + str(game_state.current_turn) + "/" + str(game_state.max_turns))
	_log_to_console("  Current player: " + game_state.current_player)
	_log_to_console("  Cards on field: " + str(game_state.field.size()))
	
	for player_name in game_state.players.keys():
		var player_data = game_state.players[player_name]
		_log_to_console("  👤 " + player_name + ": $" + str(player_data.wealth) + " (+$" + str(player_data.income) + "/turn, " + str(player_data.hand.size()) + " cards)")

# Input для debug команд (если сервер запущен с консолью)
func _input(event):
	if not NetworkMode.is_server():
		return
		
	if event.is_action_pressed("ui_accept"):  # Space
		print_game_status()
	elif event.is_action_pressed("ui_select"):  # Tab  
		_log_to_console("📊 Server uptime: " + str(Time.get_unix_time_from_system() - get_tree().get_frame()) + " seconds")
