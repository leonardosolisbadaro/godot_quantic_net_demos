## @file test_handle_state_change_use_case.gd
## @path res://tests/test_handle_state_change_use_case.gd
##
## @description
## Verifica se as notificações nativas do QuanticNet afetam corretamente a
## máquina de estados do nosso Domínio puro (NetworkSession).
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends GutTest

const HandleConnectionStateChangeUseCase = preload(
	"res://src/use_cases/handle_connection_state_change_use_case.gd"
)
const NetworkSession = preload("res://src/domain/network_session.gd")

var _sut: HandleConnectionStateChangeUseCase
var _session: NetworkSession


func before_each() -> void:
	_session = NetworkSession.new()
	_sut = HandleConnectionStateChangeUseCase.new(_session)


func after_each() -> void:
	_session = null
	_sut = null


func test_deve_registrar_sucesso_quando_recebe_status_connected() -> void:
	_session.start_connection()

	# QuanticNet.ConnectionState.CONNECTED = 3 (veja API_PUBLIC.md)
	_sut.execute(3)

	assert_eq(_session.current_state, NetworkSession.State.CONNECTED, "Sessão deve estar conectada")


func test_deve_registrar_falha_quando_recebe_status_failed() -> void:
	_session.start_connection()

	# QuanticNet.ConnectionState.FAILED = 4
	_sut.execute(4)

	assert_eq(
		_session.current_state,
		NetworkSession.State.FAILED,
		"Sessão deve registrar a falha de handshake",
	)


func test_deve_limpar_sessao_quando_desconecta() -> void:
	_session.start_connection()
	_session.set_connected()

	# QuanticNet.ConnectionState.DISCONNECTED = 0
	_sut.execute(0)

	assert_eq(
		_session.current_state,
		NetworkSession.State.DISCONNECTED,
		"Sessão deve voltar ao estágio inicial",
	)
