## @file telemetry_adapter.gd
## @path res://src/adapters/telemetry_adapter.gd
##
## @description
## Adapter que serve de ponte entre a Engine (UI, _process loop) e
## o Caso de Uso de telemetria. Orquestra a conexão via QuanticNet.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
class_name TelemetryAdapter
extends Node

signal metrics_updated(data: Dictionary)
signal connection_state_changed(state_name: String, is_connected: bool)

const PollTelemetryUseCase = preload("res://src/use_cases/poll_telemetry_use_case.gd")
const AdvancedTelemetryProfiler = preload("res://src/domain/advanced_telemetry_profiler.gd")

var _use_case: PollTelemetryUseCase
var _qn: Node


func _ready() -> void:
	var profiler = AdvancedTelemetryProfiler.new(200) # Janela de 200 amostras
	_qn = get_node("/root/QuanticNet")
	_use_case = PollTelemetryUseCase.new(profiler, _qn)

	if _qn:
		_qn.connection_state_changed.connect(_on_qn_state_changed)


func _process(_delta: float) -> void:
	if not _qn or _qn.get_state() != QuanticNet.ConnectionState.CONNECTED:
		return

	var data = _use_case.execute()
	metrics_updated.emit(data)


func _physics_process(delta: float) -> void:
	if not _qn or _qn.get_state() != QuanticNet.ConnectionState.CONNECTED:
		return

	# A demo_main.gd nos ensina que pacotes de rede DEVEM ser enviados no
	# _physics_process (Tick Rate fixo, ex: 60Hz), e não no _process (destravado),
	# para evitar Spam UDP e Bufferbloat no ENet.
	if not _qn.is_server():
		_qn.submit_state(Vector3.ZERO, Vector3.ZERO, 0, delta)


func host_server(port: int, secret: String) -> void:
	if _qn:
		_qn.host(port, secret)


func join_client(ip: String, port: int, secret: String, use_netem: bool) -> void:
	if _qn:
		var config = { }
		if use_netem:
			# Simula latência base de 100ms, oscilação de 50ms, e 5% de perda de pacotes
			config = { "netem_latency": 100, "netem_jitter": 50, "netem_loss": 0.05 }
		_qn.join(ip, port, secret, use_netem, config)


func disconnect_peer() -> void:
	if _qn:
		_qn.disconnect_net()


func _on_qn_state_changed(st: int) -> void:
	var state_name = "UNKNOWN"
	var is_connected = false
	if _qn:
		# Resolvemos o nome via dicionário interno do autoload para não vazar a dependência p/ UI
		state_name = _qn.ConnectionState.keys()[st]
		is_connected = (st == _qn.ConnectionState.CONNECTED)

	connection_state_changed.emit(state_name, is_connected)
