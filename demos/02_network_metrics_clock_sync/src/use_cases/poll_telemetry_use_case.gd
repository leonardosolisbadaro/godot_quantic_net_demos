## @file poll_telemetry_use_case.gd
## @path res://src/use_cases/poll_telemetry_use_case.gd
##
## @description
## Busca estatísticas brutas de rede da engine (QuanticNet), injeta
## na nossa calculadora matemática de Domínio e retorna os dados mastigados.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

class_name PollTelemetryUseCase
extends RefCounted

var _profiler: Object
var _gateway: Object
var _server_peer_id: int = 1

func _init(profiler: Object, gateway: Object) -> void:
	_profiler = profiler
	_gateway = gateway

func execute() -> Dictionary:
	var output = {
		"rtt_current": 0.0,
		"rtt_avg": 0.0,
		"rtt_1_low": 0.0,
		"loss_pct": 0.0
	}
	
	if not _gateway:
		return output
		
	var target_id = _gateway.get_unique_id() if _gateway.has_method("get_unique_id") else 1
	var agg = _gateway.get_telemetry(target_id)
	if not agg:
		return output
		
	var current_rtt = agg.get_current_rtt()
	_profiler.push_rtt(current_rtt)
	
	output["rtt_current"] = current_rtt
	output["rtt_avg"] = agg.get_avg_rtt()
	output["rtt_1_low"] = _profiler.get_1_percent_low_rtt()
	output["loss_pct"] = agg.get_current_loss()
	
	return output
