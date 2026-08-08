## @file interpolate_remote_entities_use_case.gd
## @path res://src/use_cases/interpolate_remote_entities_use_case.gd
##
## @description
## Orquestra a busca do último estado recebido na rede (via Gateway)
## e delega a matemática de interpolação à Entidade SnapshotInterpolator,
## blindando o _process da Godot de conhecer o funcionamento interno.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name InterpolateRemoteEntitiesUseCase
extends RefCounted

var SnapshotInterpolator = preload("res://src/domain/snapshot_interpolator.gd")
var _gateway: Object

func _init(gateway: Object) -> void:
	_gateway = gateway

## Recupera o alvo pela rede e computa a interpolação.
## Retorna o novo Vector3 interpolado para ser aplicado visualmente.
func execute(entity_id: int, current_visual_pos: Vector3, weight: float) -> Vector3:
	var state = _gateway.remote_state(entity_id)
	
	if state.is_empty():
		return current_visual_pos
		
	var target_pos = state.get("pos", current_visual_pos)
	return SnapshotInterpolator.interpolate(current_visual_pos, target_pos, weight)
