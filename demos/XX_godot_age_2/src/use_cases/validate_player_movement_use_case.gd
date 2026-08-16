## @file validate_player_movement_use_case.gd
## @path res://src/use_cases/validate_player_movement_use_case.gd
##
## @description
## Caso de uso que orquestra a validação do input do jogador contra a física
## do sampler de terreno do servidor.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

const ServerMovementValidator = preload("../domain/server_movement_validator.gd")
const HeightfieldSampler = preload("../domain/heightfield_sampler.gd")

var _validator: ServerMovementValidator


func _init() -> void:
	_validator = ServerMovementValidator.new()


func execute(
	current_pos: Vector3,
	requested_pos: Vector3,
	delta_time: float,
	max_speed: float,
	sampler: HeightfieldSampler
) -> Dictionary:
	return _validator.validate_movement(current_pos, requested_pos, delta_time, max_speed, sampler)
