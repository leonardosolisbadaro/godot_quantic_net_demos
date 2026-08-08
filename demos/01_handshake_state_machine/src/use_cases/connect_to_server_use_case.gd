## @file connect_to_server_use_case.gd
## @path res://src/use_cases/connect_to_server_use_case.gd
##
## @description
## Orquestra a intenção do jogador de conectar-se ao servidor.
## Faz a ponte entre a Entidade de Domínio (NetworkSession) e o 
## Gateway de Infraestrutura (QuanticNet).
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name ConnectToServerUseCase
extends RefCounted

var _session: NetworkSession
var _gateway: Object # Espera-se um objeto que possua o método 'join'

func _init(session: NetworkSession, gateway: Object) -> void:
	_session = session
	_gateway = gateway

## Executa o caso de uso. Retorna true se a intenção for válida e despachada.
func execute(ip: String, port: int, secret: String) -> bool:
	if _session.start_connection():
		_gateway.join(ip, port, secret)
		return true
	
	return false
