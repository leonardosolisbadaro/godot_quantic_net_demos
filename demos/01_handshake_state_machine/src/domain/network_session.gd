## @file network_session.gd
## @path res://src/domain/network_session.gd
##
## @description
## Entidade de domínio puro que encapsula o estado da conexão do usuário.
## Totalmente agnóstica à Engine ou ao plugin QuanticNet, ela apenas dita as
## regras de transição de estado da conexão.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
class_name NetworkSession
extends RefCounted

enum State {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	FAILED,
}

var current_state: State = State.DISCONNECTED


func start_connection() -> bool:
	if current_state == State.CONNECTED or current_state == State.CONNECTING:
		return false

	current_state = State.CONNECTING
	return true


func set_connected() -> void:
	if current_state == State.CONNECTING:
		current_state = State.CONNECTED


func set_failed() -> void:
	current_state = State.FAILED


func disconnect_session() -> void:
	current_state = State.DISCONNECTED
