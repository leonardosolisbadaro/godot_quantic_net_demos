## @file quantic_net_adapter.gd
## @path res://src/adapters/quantic_net_adapter.gd
##
## @description
## Atua como controlador/presenter de fronteira. Ele compõe o domínio e os casos de uso,
## e escuta os eventos globais do QuanticNet, agindo como barreira protetora para a UI.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
class_name QuanticNetAdapter
extends Node

signal session_state_updated(new_state: int)

var _session: NetworkSession
var _connect_use_case: ConnectToServerUseCase
var _handle_state_use_case: HandleConnectionStateChangeUseCase


func _ready() -> void:
	# Composição de Dependências (Dependency Injection root)
	_session = NetworkSession.new()

	# Usamos o Autoload QuanticNet como Gateway real
	var gateway = get_node_or_null("/root/QuanticNet")
	if gateway == null:
		push_error("QuanticNet Autoload não encontrado!")
		return

	_connect_use_case = ConnectToServerUseCase.new(_session, gateway)
	_handle_state_use_case = HandleConnectionStateChangeUseCase.new(_session)

	# Escuta a engine nativa C++
	gateway.connection_state_changed.connect(_on_connection_state_changed)


func host_server(port: int, secret: String) -> void:
	var gateway = get_node_or_null("/root/QuanticNet")
	if gateway:
		gateway.host(port, secret)


func join_server(ip: String, port: int, secret: String) -> void:
	if _connect_use_case.execute(ip, port, secret):
		_emit_state()


func get_current_state_name() -> String:
	match _session.current_state:
		NetworkSession.State.DISCONNECTED:
			return "DISCONNECTED"
		NetworkSession.State.CONNECTING:
			return "CONNECTING"
		NetworkSession.State.CONNECTED:
			return "CONNECTED"
		NetworkSession.State.FAILED:
			return "FAILED"
		_:
			return "UNKNOWN"


func _on_connection_state_changed(native_state: int) -> void:
	_handle_state_use_case.execute(native_state)
	_emit_state()


func _emit_state() -> void:
	session_state_updated.emit(_session.current_state)
