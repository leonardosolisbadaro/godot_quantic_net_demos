## @file test_connect_to_server_use_case.gd
## @path res://tests/test_connect_to_server_use_case.gd
##
## @description
## Testes para o caso de uso de iniciar conexão.
## Utiliza double objects (Mock) para o Gateway de Rede, validando a orquestração
## entre a Entidade (NetworkSession) e a Infraestrutura (Gateway).
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const ConnectToServerUseCase = preload("res://src/use_cases/connect_to_server_use_case.gd")
const NetworkSession = preload("res://src/domain/network_session.gd")

var _sut: ConnectToServerUseCase
var _session: NetworkSession
var _mock_gateway: MockGateway

class MockGateway:
	var join_called := false
	var join_args := []
	func join(ip: String, port: int, secret: String) -> void:
		join_called = true
		join_args = [ip, port, secret]

func before_each() -> void:
	_session = NetworkSession.new()
	_mock_gateway = MockGateway.new()
	_sut = ConnectToServerUseCase.new(_session, _mock_gateway)

func after_each() -> void:
	_session = null
	_sut = null
	_mock_gateway = null

func test_deve_chamar_o_gateway_e_transitar_estado_quando_desconectado() -> void:
	# Act
	var result = _sut.execute("127.0.0.1", 4242, "secret")
	
	# Assert
	assert_true(result, "O use case deve retornar sucesso")
	assert_eq(_session.current_state, NetworkSession.State.CONNECTING, "O estado da sessão deve mudar para CONNECTING")
	assert_true(_mock_gateway.join_called, "Gateway deve ser acionado")
	assert_eq(_mock_gateway.join_args, ["127.0.0.1", 4242, "secret"])

func test_nao_deve_chamar_gateway_se_ja_estiver_conectando() -> void:
	# Arrange
	_session.start_connection() # Força para CONNECTING
	
	# Act
	var result = _sut.execute("127.0.0.1", 4242, "secret")
	
	# Assert
	assert_false(result, "Deve rejeitar nova conexão")
	assert_false(_mock_gateway.join_called, "Não deve acionar a rede nativa")

