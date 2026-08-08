## @file test_poll_telemetry_use_case.gd
## @path res://tests/test_poll_telemetry_use_case.gd
##
## @description
## Testes para o orquestrador que coleta dados brutos de telemetria do QuanticNet,
## processa-os no nosso Domínio (para o 1% Low) e cospe um pacote consolidado para a UI.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
extends GutTest

const PollTelemetryUseCase = preload("res://src/use_cases/poll_telemetry_use_case.gd")
const AdvancedTelemetryProfiler = preload("res://src/domain/advanced_telemetry_profiler.gd")

var _sut: PollTelemetryUseCase
var _domain: AdvancedTelemetryProfiler
var _mock_gateway: MockGateway


func before_each() -> void:
	_domain = AdvancedTelemetryProfiler.new(100)
	_mock_gateway = MockGateway.new()
	_sut = PollTelemetryUseCase.new(_domain, _mock_gateway)


func after_each() -> void:
	_domain = null
	_mock_gateway = null
	_sut = null


func test_deve_retornar_dicionario_com_metricas_formatadas() -> void:
	# Act
	var result = _sut.execute()

	# Assert
	assert_eq(result["rtt_current"], 42.0, "Deve ler o RTT atual do gateway")
	assert_eq(result["rtt_avg"], 40.0, "Deve ler a media do gateway")
	assert_eq(result["loss_pct"], 2.5, "Deve ler o packet loss do gateway")
	assert_eq(
		result["rtt_1_low"],
		42.0,
		"Como é a primeira amostra, o 1% low deve ser igual ao rtt_current",
	)


func test_deve_retornar_zeros_se_gateway_nao_tem_telemetria() -> void:
	# Arrange
	_mock_gateway.server_id = 999 # Erro intencional para retornar null

	# Act
	var result = _sut.execute()

	# Assert
	assert_eq(result["rtt_current"], 0.0)
	assert_eq(result["loss_pct"], 0.0)


# Um mock simples simulando o QuanticNet.get_telemetry()
class MockGateway:
	var mock_aggregator = MockQNTelemetryAggregator.new()
	var server_id: int = 1


	func get_telemetry(peer_id: int) -> Object:
		if peer_id == server_id:
			return mock_aggregator
		return null


class MockQNTelemetryAggregator:
	var rtt: float = 42.0
	var avg_rtt: float = 40.0
	var loss: float = 2.5


	func get_current_rtt() -> float:
		return rtt


	func get_avg_rtt() -> float:
		return avg_rtt


	func get_current_loss() -> float:
		return loss
