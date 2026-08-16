## @file test_server_movement_validator.gd
## @path res://tests/test_server_movement_validator.gd
##
## @description
## Testes unitários para o validador autoritativo de movimentação ServerMovementValidator.
## Valida proteção contra speed-hack, fly-hack e queda no vazio.
## SUT: ServerMovementValidator
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

const HeightfieldSampler = preload("../src/domain/heightfield_sampler.gd")
const ServerMovementValidator = preload("../src/domain/server_movement_validator.gd")

var _validator: ServerMovementValidator
var _sampler: HeightfieldSampler


func before_each() -> void:
	_validator = ServerMovementValidator.new()
	# Terreno plano de 10m de altitude
	var heights = PackedFloat32Array([10.0, 10.0, 10.0, 10.0])
	_sampler = HeightfieldSampler.new(
		heights, 2, 2, 50.0, 50.0,
		Vector3(25.0, 0.0, 25.0), 50.0, 50.0
	)


func test_movimento_valido_aceito_sem_alteracao() -> void:
	# Arrange: Jogador em (10, 10, 10) movendo 2m para (12, 10, 10) em 0.1s (Velocidade = 20 m/s <= max 30 m/s)
	var cur_pos = Vector3(10.0, 10.0, 10.0)
	var req_pos = Vector3(12.0, 10.0, 10.0)
	var delta_t = 0.1
	var max_speed = 30.0

	# Act
	var result = _validator.validate_movement(cur_pos, req_pos, delta_t, max_speed, _sampler)

	# Assert
	assert_true(result.valid, "Movimento dentro do limite deve ser valido")
	assert_almost_eq(result.corrected_position.x, 12.0, 0.01)
	assert_almost_eq(result.corrected_position.y, 10.0, 0.01)


func test_speed_hack_bloqueado_e_clampado() -> void:
	# Arrange: Jogador em (10, 10, 10) tentando mover 100m para (110, 10, 10) em 0.1s (Velocidade = 1000 m/s!)
	var cur_pos = Vector3(10.0, 10.0, 10.0)
	var req_pos = Vector3(110.0, 10.0, 10.0)
	var delta_t = 0.1
	var max_speed = 30.0 # Máximo permitido no passo: 30 * 0.1 * 1.25 = 3.75m

	# Act
	var result = _validator.validate_movement(cur_pos, req_pos, delta_t, max_speed, _sampler)

	# Assert
	assert_false(result.valid, "Movimento com velocidade excessiva deve ser invalidado")
	var dist_percorrida = cur_pos.distance_to(Vector3(result.corrected_position.x, 10.0, result.corrected_position.z))
	assert_true(dist_percorrida <= 3.8, "Deslocamento corrigido deve respeitar o limite máximo")


func test_fly_hack_forca_ground_clamping() -> void:
	# Arrange: Jogador tentando flutuar em Y = 500m (chão real é 10m)
	var cur_pos = Vector3(10.0, 10.0, 10.0)
	var req_pos = Vector3(10.0, 500.0, 10.0)

	# Act
	var result = _validator.validate_movement(cur_pos, req_pos, 0.1, 30.0, _sampler)

	# Assert
	assert_false(result.valid, "Fly-hack deve ser rejeitado")
	assert_almost_eq(result.corrected_position.y, 10.0, 0.1, "Altitude deve ser ajustada para o solo")
