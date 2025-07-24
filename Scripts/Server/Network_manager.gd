extends Node

# ============= СИГНАЛЫ =============
signal game_action_received(action_data: Dictionary)
signal player_connected(player_id: String)
signal player_disconnected(player_id: String)
signal connection_established
signal connection_failed_signal
signal server_started

# ============= ПЕРЕМЕННЫЕ =============
var multiplayer_peer: ENetMultiplayerPeer
var connected_clients: Dictionary = {}  # peer_id: {player_name, deck_data}
var is_connected: bool = false
var my_peer_id: int = 0

# Серверные компоненты
var server_game_state: ServerGameState
var server_card_validator: ServerCardValidator
var game_manager: GameManager
var clients_ready_for_game: Dictionary = {}  # peer_id: bool

# Состояние лобби
var lobby_ready_status: Dictionary = {}  # player_name: bool

# ============= ИНИЦИАЛИЗАЦИЯ =============
func _ready():
	pass
	

func _initialize_server_components():
	# ServerGameState
	print("ii")
	if not NetworkMode.is_server():
		print("Error: _process_server_action called on client!")
		return
	print("ii")
	server_game_state = preload("res://Scripts/Server/server_game_state.gd").new()
	server_game_state.name = "ServerGameState"
	add_child(server_game_state)
	
	# ServerCardValidator
	server_card_validator = preload("res://Scripts//Server/server_card_validator.gd").new()
	server_card_validator.name = "ServerCardValidator"
	add_child(server_card_validator)
	
	# GameManager
	game_manager = preload("res://Scripts/Server/game_manager.gd").new()
	game_manager.name = "GameManager"
	add_child(game_manager)
	

# ============= ПОДКЛЮЧЕНИЕ =============
func start_server() -> bool:
	print("Starting server on port ", NetworkMode.server_port)
	
	_initialize_server_components()
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(NetworkMode.server_port, 2)
	if error != OK:
		print("Failed to start server: ", error)
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("Server started successfully")
	server_started.emit()
	return true

func connect_to_server() -> bool:
	print("Connecting to server at ", NetworkMode.server_address)
	
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(NetworkMode.server_address, NetworkMode.server_port)
	if error != OK:
		print("Failed to connect to server: ", error)
		return false
	
	multiplayer.multiplayer_peer = multiplayer_peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	return true

# ============= ОТПРАВКА ДЕЙСТВИЙ =============
func send_game_action(action_type: String, data: Dictionary):
	var message = {
		"type": action_type,
		"player_id": PlayerDatabase.current_user,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	if NetworkMode.is_server():
		message["sender_peer_id"] = 1
		_process_server_action(message)
	else:
		_request_action_from_server.rpc_id(1, message)

# ============= RPC ФУНКЦИИ =============
@rpc("any_peer", "call_remote", "reliable")
func _request_action_from_server(message: Dictionary):
	message["sender_peer_id"] = multiplayer.get_remote_sender_id()
	print("Server received: ", message.type, " from ", message.player_id)
	_process_server_action(message)

@rpc("authority", "call_local", "reliable")
func _broadcast_game_update(update_data: Dictionary):
	print("Received game update: ", update_data.type)
	game_action_received.emit(update_data)

@rpc("authority", "call_remote", "reliable")
func _send_private_update(update_data: Dictionary):
	print("Client ", multiplayer.get_unique_id(), " received private update: ", update_data.type, " - ", update_data)
	game_action_received.emit(update_data)

@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String, deck_data: Array):
	if not NetworkMode.is_server():
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	connected_clients[peer_id] = {
		"player_name": player_name,
		"deck_data": deck_data
	}
	
	print("Player registered: ", player_name, " with ", deck_data.size(), " cards")
	player_connected.emit(player_name)
	# НЕ добавляем в лобби автоматически - SimpleLobbyManager сделает это

# ============= ОБРАБОТКА ДЕЙСТВИЙ НА СЕРВЕРЕ =============
func _process_server_action(message: Dictionary):
	if not NetworkMode.is_server():
		print("Error: _process_server_action called on client!")
		return
	match message.type:
		# Лобби
		"join_lobby":
			_handle_join_lobby(message)
		"player_ready":
			_handle_player_ready(message)
		
		# Игровые действия
		"request_card_play":
			_handle_card_play_request(message)
		"request_draw_card":
			_handle_draw_card_request(message)
		"request_end_turn":
			_handle_end_turn_request(message)
		"request_start_game":
			_handle_start_game_request(message)
		_:
			print("Unknown action: ", message.type)

# ============= ОБРАБОТЧИКИ ЛОББИ =============
func _handle_join_lobby(message: Dictionary):
	var player_name = message.data.player_name
	lobby_ready_status[player_name] = false
	
	print("Player joined lobby: ", player_name)
	_broadcast_lobby_state()

func _handle_player_ready(message: Dictionary):
	var player_name = message.data.player_name
	var is_ready = message.data.is_ready
	
	lobby_ready_status[player_name] = is_ready
	
	print("Player ready status: ", player_name, " = ", is_ready)
	_broadcast_lobby_state()
	
	# Проверяем готовность начать игру
	_check_auto_start()

func _broadcast_lobby_state():
	_broadcast_game_update.rpc({
		"type": "lobby_update",
		"data": {"players": lobby_ready_status}
	})

func _check_auto_start():
	if lobby_ready_status.size() < 2:
		return
	
	for is_ready in lobby_ready_status.values():
		if not is_ready:
			return
	
	# Все готовы - запускаем игру
	print("All players ready! Starting game...")
	_start_game()

# ============= ОБРАБОТЧИКИ ИГРЫ =============
func _handle_start_game_request(message: Dictionary):
	_start_game()

func _start_game():
	if not NetworkMode.is_server():
		return
	
	var player_list = lobby_ready_status.keys()
	
	# Initialize players
	for peer_id in connected_clients:
		var client_data = connected_clients[peer_id]
		var player_name = client_data.player_name
		if player_name in player_list:
			server_game_state.initialize_player(player_name, client_data.deck_data)
	
	# Tell clients to change scenes
	_broadcast_game_update.rpc({
		"type": "game_start",
		"data": {}
	})
	
	# Wait for clients to confirm they're ready
	print("Waiting for clients to load battle scene...")
	await _wait_for_clients_ready()
	
	print("All clients ready, starting game!")
	
	# Now actually start
	if game_manager and game_manager.start_game(player_list):
		_deal_starting_hands()

# Add function to wait for clients:
func _wait_for_clients_ready():
	clients_ready_for_game.clear()
	
	# Wait up to 10 seconds for clients
	var timeout = 10.0
	var check_interval = 0.1
	var time_waited = 0.0
	
	while time_waited < timeout:
		var all_ready = true
		for peer_id in connected_clients:
			if peer_id != 1 and not peer_id in clients_ready_for_game:
				all_ready = false
				break
		
		if all_ready and clients_ready_for_game.size() >= lobby_ready_status.size() - 1:
			return
		
		await get_tree().create_timer(check_interval).timeout
		time_waited += check_interval
	
	print("Warning: Timeout waiting for clients!")

# Add RPC for client confirmation:
@rpc("any_peer", "call_remote", "reliable")
func _confirm_battle_scene_ready():
	var peer_id = multiplayer.get_remote_sender_id()
	print("Client ", peer_id, " confirmed ready")
	clients_ready_for_game[peer_id] = true
	
func _deal_starting_hands():
	print("Dealing starting hands...")
	
	for player_name in server_game_state.players.keys():
		var starting_cards = []
		
		# Берем 4 карты для каждого игрока
		for i in range(4):
			var card_name = server_game_state.draw_card_for_player(player_name)
			if card_name != "":
				starting_cards.append(card_name)
		
		# Отправляем всю начальную руку одним пакетом
		var peer_id = _get_peer_id_for_player(player_name)
		if peer_id > 0:
			_send_private_update.rpc_id(peer_id, {
				"type": "initial_hand",
				"data": {"cards": starting_cards}
			})
			
			print("Sent ", starting_cards.size(), " cards to ", player_name)

func _handle_card_play_request(message: Dictionary):
	var player_id = message.player_id
	var card_name = message.data.get("card_name", "")
	var hex_pos = Vector2i(
		message.data.hex_position.x,
		message.data.hex_position.y
	)
	var request_id = message.data.get("request_id", "")
	var sender_peer = message.sender_peer_id
	
	# Проверка очередности хода
	if game_manager and game_manager.turn_manager:
		if game_manager.turn_manager.current_player != player_id:
			_send_private_update.rpc_id(sender_peer, {
				"type": "error",
				"data": {"message": "Not your turn"}
			})
			return
	
	# 1. Валидация
	var validation_result = server_card_validator.validate_card_play(
		player_id, card_name, hex_pos
	)
	
	# 2. Ответ запросившему игроку
	_send_private_update.rpc_id(sender_peer, {
		"type": "card_play_response",
		"data": {
			"request_id": request_id,
			"approved": validation_result.valid,
			"reason": validation_result.get("reason", "")
		}
	})
	
	# 3. Если одобрено - обновляем состояние сервера и уведомляем
	if validation_result.valid:
		# Получаем данные карты для эффектов
		var card_instance = CardDatabase.create_card_instance(card_name)
		
		# Обновляем доход если карта дает бонус
		if card_instance and card_instance.has_method("get_income_boost"):
			var income_boost = card_instance.call("get_income_boost")
			server_game_state.add_player_income(player_id, income_boost)
		
		# Освобождаем временный экземпляр
		if card_instance:
			card_instance.queue_free()
		
		# Удаляем карту из руки
		server_game_state.remove_card_from_player_hand(player_id, card_name)
		
		# === АСИММЕТРИЧНЫЕ УВЕДОМЛЕНИЯ ===
		
		# Активному игроку - подтверждение удаления из руки
		_send_private_update.rpc_id(sender_peer, {
			"type": "card_removed_from_hand",
			"data": {"card_name": card_name}
		})
		
		# Всем - обновление доски
		_broadcast_game_update.rpc({
			"type": "board_update",
			"data": {
				"hex_position": {"x": hex_pos.x, "y": hex_pos.y},
				"card_name": card_name,
				"player_id": player_id
			}
		})
		
		# Активному игроку - детальное обновление богатства
		_send_private_update.rpc_id(sender_peer, {
			"type": "wealth_update",
			"data": {
				"player_id": player_id,
				"wealth": validation_result.new_wealth,
				"spent": validation_result.get("card_cost", 0)
			}
		})
		
		# Оппонентам - только новое значение богатства
		for peer_id in connected_clients.keys():
			if peer_id != sender_peer:
				var client_player = connected_clients[peer_id].player_name
				if client_player != player_id:
					_send_private_update.rpc_id(peer_id, {
						"type": "opponent_wealth_update", 
						"data": {
							"player_id": player_id,
							"wealth": validation_result.new_wealth
						}
					})
		
		# Если доход изменился - уведомляем
		if server_game_state.players[player_id].income != 100:
			# Активному игроку
			_send_private_update.rpc_id(sender_peer, {
				"type": "income_update",
				"data": {
					"player_id": player_id,
					"income": server_game_state.players[player_id].income
				}
			})
			
			# Оппонентам
			for peer_id in connected_clients.keys():
				if peer_id != sender_peer:
					var client_player = connected_clients[peer_id].player_name
					if client_player != player_id:
						_send_private_update.rpc_id(peer_id, {
							"type": "opponent_income_update",
							"data": {
								"player_id": player_id,
								"income": server_game_state.players[player_id].income
							}
						})

func _handle_draw_card_request(message: Dictionary):
	var player_id = message.player_id
	var sender_peer = message.sender_peer_id
	
	# Проверяем, может ли игрок взять карту
	var current_phase = game_manager.turn_manager.current_phase if game_manager else null
	var current_player = game_manager.turn_manager.current_player if game_manager else ""
	
	# Можно взять только в свою основную фазу (для спец. эффектов)
	if current_player != player_id or current_phase != TurnManager.GamePhase.MAIN_PHASE:
		_send_private_update.rpc_id(sender_peer, {
			"type": "error",
			"data": {"message": "Cannot draw card now"}
		})
		return
	
	var card_name = server_game_state.draw_card_for_player(player_id)
	
	if card_name != "":
		_send_private_update.rpc_id(sender_peer, {
			"type": "card_drawn",
			"data": {"card_name": card_name}
		})
	else:
		_send_private_update.rpc_id(sender_peer, {
			"type": "deck_empty_notification",
			"data": {}
		})

func _handle_end_turn_request(message: Dictionary):
	var player_id = message.player_id
	
	if game_manager and game_manager.turn_manager:
		var success = game_manager.turn_manager.process_end_turn_request(player_id)
		if not success:
			_send_private_update.rpc_id(message.sender_peer_id, {
				"type": "error",
				"data": {"message": "Cannot end turn now"}
			})

# ============= ОБРАБОТЧИКИ ПОДКЛЮЧЕНИЙ =============
func _on_peer_connected(peer_id: int):
	print("Peer connected: ", peer_id)

func _on_peer_disconnected(peer_id: int):
	if peer_id in connected_clients:
		var player_data = connected_clients[peer_id]
		var player_name = player_data.get("player_name", "")
		connected_clients.erase(peer_id)
		
		# Удаляем из лобби
		if player_name in lobby_ready_status:
			lobby_ready_status.erase(player_name)
			_broadcast_lobby_state()
		
		player_disconnected.emit(player_name)

func _on_connected_to_server():
	is_connected = true
	my_peer_id = multiplayer.get_unique_id()
	connection_established.emit()
	
	# Регистрируемся с колодой
	var deck_data = DeckData.get_deck()
	_register_player.rpc_id(1, PlayerDatabase.current_user, deck_data)

func _on_connection_failed():
	is_connected = false
	connection_failed_signal.emit()

func _on_server_disconnected():
	is_connected = false

# ============= УТИЛИТЫ =============
func _get_peer_id_for_player(player_name: String) -> int:
	for peer_id in connected_clients.keys():
		if connected_clients[peer_id].player_name == player_name:
			return peer_id
	return 0

func get_connected_players() -> Array:
	return lobby_ready_status.keys()

func disconnect_from_network():
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
	is_connected = false
	connected_clients.clear()
	lobby_ready_status.clear()
		
