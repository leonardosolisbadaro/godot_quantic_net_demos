## @file test_network_session.gd
## @path res://tests/test_network_session.gd
##
## @description
## Testes unitários focados na entidade de domínio NetworkSession (State Machine).
## Verifica as regras de negócio puras (transição de estados) de forma isolada do ENet.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const NetworkSession = preload("res://src/domain/network_session.gd")

var _sut: NetworkSession

func before_each() -> void:
	# Arrange (Setup SUT)
	_sut = NetworkSession.new()

func after_each() -> void:
	_sut = null

func test_estado_inicial_deve_ser_disconnected() -> void:
	# Assert
	assert_eq(_sut.current_state, NetworkSession.State.DISCONNECTED, "Sessão recém criada deve estar desconectada")

func test_iniciar_conexao_deve_mudar_estado_para_connecting() -> void:
	# Act
	_sut.start_connection()
	
	# Assert
	assert_eq(_sut.current_state, NetworkSession.State.CONNECTING, "Ao chamar start_connection, o estado deve transitar para CONNECTING")

func test_nao_deve_permitir_conectar_se_ja_estiver_conectado() -> void:
	# Arrange
	_sut.start_connection()
	_sut.set_connected()
	assert_eq(_sut.current_state, NetworkSession.State.CONNECTED, "[Pre-Condição] O estado atual deve ser CONNECTED")
	
	# Act
	var result = _sut.start_connection()
	
	# Assert
	assert_false(result, "O comando de conectar deve retornar falso se já estiver conectado")
	assert_eq(_sut.current_state, NetworkSession.State.CONNECTED, "O estado deve permanecer intacto (CONNECTED)")
