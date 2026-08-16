## @file test_heightfield_sampler.gd
## @path res://tests/test_heightfield_sampler.gd
##
## @description
## Testes unitários para a entidade de domínio HeightfieldSampler.
## Valida a amostragem matemática e a interpolação bilinear em O(1).
## SUT: HeightfieldSampler
##
## @created 2026-08-15
## @updated 2026-08-15
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends "res://addons/gut/test.gd"

const HeightfieldSampler = preload("../src/domain/heightfield_sampler.gd")

var _sampler: HeightfieldSampler


func before_each() -> void:
	# Cria uma grade sintética 2x2 células (3x3 vértices) com espaçamento de 10m
	# Vértices (Row 0): (0,0)=0m,   (10,0)=10m,  (20,0)=20m
	# Vértices (Row 1): (0,10)=10m, (10,10)=20m, (20,10)=30m
	# Vértices (Row 2): (0,20)=20m, (10,20)=30m, (20,20)=40m
	var heights = PackedFloat32Array([
		0.0, 10.0, 20.0,
		10.0, 20.0, 30.0,
		20.0, 30.0, 40.0
	])
	_sampler = HeightfieldSampler.new(
		heights,
		3, 3,        # 3x3 vértices
		10.0, 10.0,  # cell_size = 10m
		Vector3(10.0, 0.0, 10.0), # world_origin (centro da grade)
		20.0, 20.0   # total width/depth = 20m
	)


func test_amostragem_cantos_exatos() -> void:
	# Arrange & Act
	# Origem local (0, 0) no mundo = (X=0, Z=0)
	var h_canto_tl = _sampler.get_height_at(0.0, 0.0)
	var h_centro = _sampler.get_height_at(10.0, 10.0)
	var h_canto_br = _sampler.get_height_at(20.0, 20.0)

	# Assert
	assert_almost_eq(h_canto_tl, 0.0, 0.01, "Canto superior esquerdo deve ser 0m")
	assert_almost_eq(h_centro, 20.0, 0.01, "Centro da grade deve ser 20m")
	assert_almost_eq(h_canto_br, 40.0, 0.01, "Canto inferior direito deve ser 40m")


func test_interpolacao_bilinear_sub_celula() -> void:
	# Arrange: Ponto a meio caminho entre (0,0)=0m e (10,0)=10m -> (5, 0) = 5m
	# Act
	var h_meio_x = _sampler.get_height_at(5.0, 0.0)
	# Ponto no centro do quad 0: entre (0,0)=0, (10,0)=10, (0,10)=10, (10,10)=20 -> (5,5) = 10m
	var h_centro_quad = _sampler.get_height_at(5.0, 5.0)

	# Assert
	assert_almost_eq(h_meio_x, 5.0, 0.01, "Interpolação linear em X deve ser 5m")
	assert_almost_eq(h_centro_quad, 10.0, 0.01, "Interpolação bilinear no centro do quad deve ser 10m")


func test_coordenadas_fora_dos_limites_fazem_clamp() -> void:
	# Arrange & Act
	var h_fora_min = _sampler.get_height_at(-50.0, -50.0)
	var h_fora_max = _sampler.get_height_at(100.0, 100.0)

	# Assert
	assert_almost_eq(h_fora_min, 0.0, 0.01, "Fora do limite inferior deve fazer clamp para 0m")
	assert_almost_eq(h_fora_max, 40.0, 0.01, "Fora do limite superior deve fazer clamp para 40m")
