## @file handle_connection_state_change_use_case.gd
## @path res://src/use_cases/handle_connection_state_change_use_case.gd
##
## @description
## Transita o estado do Domínio com base nos códigos recebidos da infraestrutura.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name HandleConnectionStateChangeUseCase
extends RefCounted

var _session: NetworkSession

func _init(session: NetworkSession) -> void:
	_session = session

## Executa a transição. Espera o Enum inteiro vindo do QuanticNet.
func execute(quantic_net_state: int) -> void:
	match quantic_net_state:
		0: # DISCONNECTED
			_session.disconnect_session()
		3: # CONNECTED
			_session.set_connected()
		4: # FAILED
			_session.set_failed()
		_: # 1 e 2 são intermediários que nossa camada de domínio não se importa por enquanto
			pass
