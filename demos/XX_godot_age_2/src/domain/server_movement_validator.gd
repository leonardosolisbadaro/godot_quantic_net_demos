## @file server_movement_validator.gd
## @path res://src/domain/server_movement_validator.gd
##
## @description
## Validador de domínio puro para regras de movimentação autoritativa do servidor.
## Bloqueia speed-hack, fly-hack e realiza ground clamping.
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

const HeightfieldSampler = preload("heightfield_sampler.gd")

const MAX_SPEED_TOLERANCE_FACTOR := 1.25
const MAX_VERTICAL_FLY_TOLERANCE := 2.5


func validate_movement(
	current_pos: Vector3,
	requested_pos: Vector3,
	delta_time: float,
	max_speed: float,
	sampler: HeightfieldSampler
) -> Dictionary:
	var dt = maxf(delta_time, 0.001)
	var max_step_dist = max_speed * dt * MAX_SPEED_TOLERANCE_FACTOR

	# 1. Validação de Deslocamento Horizontal (Anti-Speed e Anti-Teleport)
	var delta_horiz = Vector2(requested_pos.x - current_pos.x, requested_pos.z - current_pos.z)
	var requested_dist = delta_horiz.length()
	var is_speed_valid = requested_dist <= max_step_dist

	var target_x = requested_pos.x
	var target_z = requested_pos.z

	if not is_speed_valid:
		var clamped_dir = delta_horiz.normalized() * max_step_dist
		target_x = current_pos.x + clamped_dir.x
		target_z = current_pos.y if delta_horiz.is_zero_approx() else current_pos.z + clamped_dir.y

	# 2. Validação de Altitude e Solo (Anti-Fly e Ground Clamping)
	var ground_y = current_pos.y
	if sampler:
		ground_y = sampler.get_height_at(target_x, target_z)

	var target_y = requested_pos.y
	var is_altitude_valid = true

	# Se o jogador estiver flutuando acima da tolerância ou afundado no chão
	if requested_pos.y > (ground_y + MAX_VERTICAL_FLY_TOLERANCE) or requested_pos.y < (ground_y - 1.0):
		target_y = ground_y
		is_altitude_valid = false

	var is_all_valid = is_speed_valid and is_altitude_valid

	return {
		"valid": is_all_valid,
		"corrected_position": Vector3(target_x, target_y, target_z),
		"ground_height": ground_y
	}
