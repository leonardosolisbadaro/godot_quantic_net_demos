## @file entity_registry_adapter.gd
## @path res://src/adapters/entity_registry_adapter.gd
##
## @description
## Adapter responsável por escutar os sinais assíncronos da Engine QuanticNet
## e traduzi-los para os Casos de Uso (Domínio) quando no servidor, ou
## emitir sinais limpos para a Camada de Apresentação (UI) desenhar.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name EntityRegistryAdapter
extends RefCounted

signal visual_state_received(id: int, pos: Vector3, rot: Vector3)
signal visual_entity_removed(id: int)

var _gateway: Object
var _spawn_use_case: Object
var _despawn_use_case: Object
var _profile_factory: Object

func _init(gateway: Object, spawn_uc: Object, despawn_uc: Object, profile_factory: Object) -> void:
	_gateway = gateway
	_spawn_use_case = spawn_uc
	_despawn_use_case = despawn_uc
	_profile_factory = profile_factory
	
	_gateway.peer_joined.connect(_on_peer_joined)
	_gateway.peer_left.connect(_on_peer_left)
	_gateway.state_received.connect(_on_state_received)

func _on_peer_joined(id: int) -> void:
	if _gateway.is_server():
		var profile = _profile_factory.create_player_profile()
		_spawn_use_case.execute(id, true, profile)

func _on_peer_left(id: int) -> void:
	if _gateway.is_server():
		_despawn_use_case.execute(id)
	
	visual_entity_removed.emit(id)

func _on_state_received(id: int, pos: Vector3, rot: Vector3, _custom: int) -> void:
	visual_state_received.emit(id, pos, rot)
