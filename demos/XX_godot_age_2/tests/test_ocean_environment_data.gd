## @file test_ocean_environment_data.gd
## @path res://tests/test_ocean_environment_data.gd
##
## @description
## Testes unitários para a entidade de domínio OceanEnvironmentData.
## Valida valores padrão, instanciação customizada, cálculo de profundidade e serialização.
##
## @created 2026-08-16
## @updated 2026-08-16
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends GutTest

const OceanEnvironmentData = preload("res://src/domain/ocean_environment_data.gd")


func test_instanciacao_padrao() -> void:
	# Arrange & Act
	var ocean = OceanEnvironmentData.new()

	# Assert
	assert_true(ocean.enabled, "Oceano deve vir habilitado por padrão na entidade")
	assert_eq(ocean.sea_level_y, -149.0, "Nível do mar padrão deve ser -149.0m")
	assert_eq(ocean.water_murkiness, 0.08, "Murkiness padrão deve ser 0.08")
	assert_true(ocean.is_submerged(-160.0), "Ponto em Y=-160m deve estar submerso")
	assert_false(ocean.is_submerged(-120.0), "Ponto em Y=-120m deve estar acima da água")


func test_from_dictionary() -> void:
	# Arrange
	var dict = {
		"enabled": false,
		"sea_level_y": -180.0,
		"deep_color": [0.01, 0.04, 0.12, 1.0],
		"shallow_color": [0.1, 0.4, 0.5, 0.8],
		"wave_speed": 0.05,
		"foam_thickness": 1.2
	}

	# Act
	var ocean = OceanEnvironmentData.from_dictionary(dict)

	# Assert
	assert_false(ocean.enabled, "Enabled deve ser lido como false")
	assert_eq(ocean.sea_level_y, -180.0)
	assert_eq(ocean.wave_speed, 0.05)
	assert_eq(ocean.foam_thickness, 1.2)
	assert_eq(ocean.deep_color, Color(0.01, 0.04, 0.12, 1.0))
	assert_eq(ocean.shallow_color, Color(0.1, 0.4, 0.5, 0.8))


func test_calculo_profundidade() -> void:
	# Arrange
	var ocean = OceanEnvironmentData.new(-150.0)

	# Act
	var depth_submerso = ocean.get_water_depth_at(-180.0)
	var depth_superficie = ocean.get_water_depth_at(-150.0)
	var depth_seco = ocean.get_water_depth_at(-100.0)

	# Assert
	assert_eq(depth_submerso, 30.0, "Profundidade em -180m deve ser 30m")
	assert_eq(depth_superficie, 0.0, "Profundidade no nível do mar deve ser 0m")
	assert_eq(depth_seco, 0.0, "Profundidade em terra seca deve ser 0m (clampado)")
