extends Node2D

func _ready():
	if not NetworkMode.is_server():
		# Tell server we're ready
		print("Battle scene loaded, confirming to server...")
		NetworkManager._confirm_battle_scene_ready.rpc_id(1)
