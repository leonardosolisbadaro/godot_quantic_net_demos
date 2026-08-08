## @file move_local_player_use_case.gd
## @path res://src/use_cases/move_local_player_use_case.gd
##
## @description
## Orquestrador do Client-Side Prediction (CSP).
## Recebe input bruto, calcula no domínio e roteia ao Servidor UDP.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
var PlayerKinematics = preload("res://src/domain/player_kinematics.gd")
var _gateway: Object


## Injeção de Dependência do Gateway da Rede (ex: QuanticNet Autoload)
func _init(gateway: Object) -> void:
	_gateway = gateway


## Executa o cálculo e submissão de estado.
## Retorna a posição prevista localmente para atualizar a malha imediatamente.
func execute(current_pos: Vector3, input_dir: Vector3, speed: float, delta: float, inject_teleport: bool = false, submit_network: bool = true) -> Vector3:
	var predicted_pos = PlayerKinematics.calculate_next_position(
		current_pos,
		input_dir,
		speed,
		delta,
	)

	if inject_teleport:
		# Trapaça: Teleporta 2 metros pra frente ignorando a física
		# Mesmo sendo curto, como ocorre em 1 frame (~0.016s), a velocidade 
		# passa de 125 m/s, o que engatilha o Anti-Cheat do Servidor (15 m/s).
		predicted_pos.z -= 2.0

	if submit_network:
		# Envia a predição para o Gateway da engine C++ repassar autoritativamente
		_gateway.submit_state(predicted_pos, Vector3.ZERO, 0, delta)

	return predicted_pos
