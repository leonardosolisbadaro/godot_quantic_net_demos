## @file test_snapshot_interpolator.gd
## @path res://tests/test_snapshot_interpolator.gd
##
## @description
## Testes unitários para a entidade de domínio SnapshotInterpolator.
## Garante a matemática limpa de lerping (interpolação) sem acoplamento 
## aos nós da Engine.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const SnapshotInterpolator = preload("res://src/domain/snapshot_interpolator.gd")

func test_deve_retornar_posicao_atual_quando_delta_zero() -> void:
	# Arrange
	var current = Vector3(0, 0, 0)
	var target = Vector3(10, 0, 0)
	var lerp_weight = 0.0
	
	# Act
	var result = SnapshotInterpolator.interpolate(current, target, lerp_weight)
	
	# Assert
	assert_eq(result, Vector3(0, 0, 0), "Com peso 0, deve permanecer na posicao atual")

func test_deve_retornar_posicao_alvo_quando_peso_maior_ou_igual_a_um() -> void:
	# Arrange
	var current = Vector3(0, 0, 0)
	var target = Vector3(10, 0, 0)
	var lerp_weight = 1.0
	
	# Act
	var result = SnapshotInterpolator.interpolate(current, target, lerp_weight)
	
	# Assert
	assert_eq(result, Vector3(10, 0, 0), "Com peso 1, deve alcancar o alvo")
	
	result = SnapshotInterpolator.interpolate(current, target, 1.5)
	assert_eq(result, Vector3(10, 0, 0), "O peso deve ser clampado em 1.0")

func test_deve_retornar_posicao_intermediaria_com_peso_fracionado() -> void:
	# Arrange
	var current = Vector3(0, 0, 0)
	var target = Vector3(10, 0, 0)
	var lerp_weight = 0.5
	
	# Act
	var result = SnapshotInterpolator.interpolate(current, target, lerp_weight)
	
	# Assert
	assert_eq(result, Vector3(5, 0, 0), "Com peso 0.5, deve estar exatamente na metade do caminho")

func test_nao_deve_retroceder_se_peso_for_negativo() -> void:
	# Arrange
	var current = Vector3(10, 0, 0)
	var target = Vector3(20, 0, 0)
	var lerp_weight = -0.5
	
	# Act
	var result = SnapshotInterpolator.interpolate(current, target, lerp_weight)
	
	# Assert
	assert_eq(result, Vector3(10, 0, 0), "Se peso for negativo, deve retornar atual (clamp 0)")
