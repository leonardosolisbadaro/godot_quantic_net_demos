## @file quantic_net_server_adapter.gd
## @path res://src/adapters/quantic_net_server_adapter.gd
##
## @description
## Adaptador de interface que traduz eventos de rede do QuanticNet para o servidor
## dedicado, gerenciando perfis de entidades e validação autoritativa.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

const ServerWorldManager = preload("res://src/infrastructure/server_world_manager.gd")

var _world_manager: ServerWorldManager
var _active_peers: Dictionary = {}  # { peer_id: { position: Vector3, rotation: Vector3 } }


func _init(world_mgr: ServerWorldManager) -> void:
	_world_manager = world_mgr


func setup_host(qn: Node, port: int = 4242, secret: String = "secret") -> bool:
	if not qn:
		return false

	var profile_player = {
		"sync_mode": 1,          # Interpolação suave
		"presence_radius": 200.0,# Raio AoI
		"spatial_culling": true,
		"reliable": false
	}

	var global_params = {
		"server_tick_rate": 20.0,
		"max_speed": 30.0
	}

	var res = qn.host(port, secret, "127.0.0.1", 32, global_params)
	if res == OK:
		print("[SERVER] QuanticNet host inicializado com sucesso na porta: ", port)
		# Registra o perfil padrão
		if qn.has_method("register_entity"):
			qn.register_entity(1, false, true, profile_player)
		return true

	push_error("[SERVER] Falha ao inicializar host QuanticNet. Erro: %d" % res)
	return false


func on_peer_connected(peer_id: int) -> void:
	print("[SERVER] Peer conectado: #%d" % peer_id)
	_active_peers[peer_id] = {
		"position": Vector3(-2184.5, 20.0, 4056.9),
		"rotation": Vector3.ZERO
	}


func on_peer_disconnected(peer_id: int) -> void:
	print("[SERVER] Peer desconectado: #%d" % peer_id)
	_active_peers.erase(peer_id)


func validate_peer_state(peer_id: int, requested_pos: Vector3, delta_time: float) -> Vector3:
	if not _active_peers.has(peer_id):
		_active_peers[peer_id] = {"position": requested_pos, "rotation": Vector3.ZERO}

	var current_pos = _active_peers[peer_id]["position"]
	var result = _world_manager.validate_player_move(current_pos, requested_pos, delta_time)

	var valid_pos = result["corrected_position"]
	_active_peers[peer_id]["position"] = valid_pos
	return valid_pos
