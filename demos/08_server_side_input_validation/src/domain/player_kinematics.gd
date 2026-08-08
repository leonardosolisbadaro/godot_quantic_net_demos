## @file player_kinematics.gd
## @path res://src/domain/player_kinematics.gd
##
## @description
## Entidade de domínio responsável pelos cálculos de cinemática do jogador.
## Abstração puramente matemática, livre de dependências visuais.
##
## Calcula a próxima posição baseada no vetor de direção, velocidade e delta time.
## O vetor de direção será normalizado caso seu tamanho seja maior que zero.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
static func calculate_next_position(
	current_pos: Vector3,
	input_dir: Vector3,
	speed: float,
	delta: float,
) -> Vector3:
	if input_dir.length_squared() > 0:
		input_dir = input_dir.normalized()

	return current_pos + (input_dir * speed * delta)
