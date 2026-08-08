## @file despawn_authoritative_entity_use_case.gd
## @path res://src/use_cases/despawn_authoritative_entity_use_case.gd
##
## @description
## Caso de uso responsável por desregistrar uma entidade do servidor
## autoritativo (QuanticNet).
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name DespawnAuthoritativeEntityUseCase
extends RefCounted

var _gateway: Object

func _init(gateway: Object) -> void:
	_gateway = gateway

func execute(entity_id: int) -> void:
	_gateway.unregister_entity(entity_id)
