## @file spawn_authoritative_entity_use_case.gd
## @path res://src/use_cases/spawn_authoritative_entity_use_case.gd
##
## @description
## Caso de uso responsável por registrar uma nova entidade no servidor
## autoritativo (QuanticNet). Ele repassa a criação para a infraestrutura.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name SpawnAuthoritativeEntityUseCase
extends RefCounted

var _gateway: Object

func _init(gateway: Object) -> void:
	_gateway = gateway

func execute(entity_id: int, is_peer: bool, profile: QNEntityProfile) -> void:
	# O terceiro parâmetro do QuanticNet é "has_initial_state"
	# Por padrão, assumiremos verdadeiro para o instanciamento base
	_gateway.register_entity(entity_id, is_peer, true, profile)
