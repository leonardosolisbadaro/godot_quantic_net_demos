## @file test_player_kinematics.gd
## @path res://tests/test_player_kinematics.gd
##
## @description
## Testes unitários para PlayerKinematics.
## Valida a matemática de deslocamento baseado em vetor de direção e velocidade.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

var PlayerKinematics = preload("res://src/domain/player_kinematics.gd")

func test_deve_retornar_a_mesma_posicao_se_input_for_zero() -> void:
	var current_pos = Vector3(10.0, 0.0, 10.0)
	var input_dir = Vector3.ZERO
	var new_pos = PlayerKinematics.calculate_next_position(current_pos, input_dir, 5.0, 1.0)
	assert_eq(new_pos, current_pos)

func test_deve_deslocar_no_eixo_x_positivo() -> void:
	var current_pos = Vector3.ZERO
	var input_dir = Vector3(1.0, 0.0, 0.0)
	var new_pos = PlayerKinematics.calculate_next_position(current_pos, input_dir, 10.0, 0.5)
	assert_eq(new_pos, Vector3(5.0, 0.0, 0.0))

func test_deve_deslocar_na_diagonal_com_vetor_normalizado() -> void:
	var current_pos = Vector3.ZERO
	var input_dir = Vector3(1.0, 0.0, 1.0)
	# O kinematics deve normalizar o input para evitar que o jogador ande mais rápido na diagonal.
	var new_pos = PlayerKinematics.calculate_next_position(current_pos, input_dir, 10.0, 1.0)
	
	var expected_dir = Vector3(1.0, 0.0, 1.0).normalized()
	var expected_pos = expected_dir * 10.0 * 1.0
	
	# Usando is_equal_approx para tolerância a floats
	assert_true(new_pos.is_equal_approx(expected_pos))
