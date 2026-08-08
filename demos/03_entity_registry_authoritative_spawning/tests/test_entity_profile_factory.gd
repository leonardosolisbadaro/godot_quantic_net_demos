## @file test_entity_profile_factory.gd
## @path res://tests/test_entity_profile_factory.gd
##
## @description
## Testes unitários para a EntityProfileFactory, garantindo que os 
## perfis C++ (QNEntityProfile) sejam gerados com os valores corretos
## de domínio (Tick Rate, Prioridade, Culling).
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const EntityProfileFactory = preload("res://src/domain/entity_profile_factory.gd")

func test_deve_retornar_perfil_valido_para_player() -> void:
	# Arrange
	var factory = EntityProfileFactory.new()
	
	# Act
	var profile = factory.create_player_profile()
	
	# Assert
	assert_not_null(profile)
	assert_eq(profile.get_tick_rate_hz(), 60.0)
	assert_eq(profile.get_base_priority(), 1.0)
	assert_eq(profile.get_spatial_culling_radius(), 20.0)

func test_deve_retornar_perfil_valido_para_prop() -> void:
	# Arrange
	var factory = EntityProfileFactory.new()
	
	# Act
	var profile = factory.create_prop_profile()
	
	# Assert
	assert_not_null(profile)
	assert_eq(profile.get_tick_rate_hz(), 5.0)
	assert_eq(profile.get_base_priority(), 0.5)
	assert_eq(profile.get_spatial_culling_radius(), 20.0)
