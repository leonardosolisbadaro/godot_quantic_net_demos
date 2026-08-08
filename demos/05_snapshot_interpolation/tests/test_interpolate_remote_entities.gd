## @file test_interpolate_remote_entities.gd
## @path res://tests/test_interpolate_remote_entities.gd
##
## @description
## Verifica se o Use Case recupera os estados do Gateway (QuanticNet) e
## aplica corretamente a suavização (lerping) baseada na lógica de domínio.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const InterpolateRemoteEntitiesUseCase = preload("res://src/use_cases/interpolate_remote_entities_use_case.gd")

var _sut: InterpolateRemoteEntitiesUseCase
var _mock_gateway: MockGateway

func before_each() -> void:
	_mock_gateway = MockGateway.new()
	_sut = InterpolateRemoteEntitiesUseCase.new(_mock_gateway)

func test_deve_retornar_posicao_atual_se_nao_houver_estado_remoto() -> void:
	# Arrange
	_mock_gateway.mock_state = {}
	var current = Vector3(0, 0, 0)
	
	# Act
	var result = _sut.execute(42, current, 0.5)
	
	# Assert
	assert_eq(result, current, "Sem estado remoto na rede, deve manter a posicao atual")

func test_deve_interpolar_em_direcao_ao_estado_remoto() -> void:
	# Arrange
	_mock_gateway.mock_state = {"pos": Vector3(10, 0, 0)}
	var current = Vector3(0, 0, 0)
	
	# Act (Meio do caminho)
	var result = _sut.execute(42, current, 0.5)
	
	# Assert
	assert_eq(result, Vector3(5, 0, 0), "Deve interpolar 50% entre o visual e a rede")

func test_deve_fixar_na_posicao_remota_com_peso_completo() -> void:
	# Arrange
	_mock_gateway.mock_state = {"pos": Vector3(100, 50, -10)}
	var current = Vector3(0, 0, 0)
	
	# Act (Peso maximo ou delta absurdo)
	var result = _sut.execute(42, current, 2.0)
	
	# Assert
	assert_eq(result, Vector3(100, 50, -10), "Deve clamp e chegar no destino exato da rede")

class MockGateway:
	var mock_state: Dictionary = {}
	
	func remote_state(id: int) -> Dictionary:
		return mock_state
