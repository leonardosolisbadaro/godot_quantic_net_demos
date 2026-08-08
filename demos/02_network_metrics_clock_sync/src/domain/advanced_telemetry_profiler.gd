## @file advanced_telemetry_profiler.gd
## @path res://src/domain/advanced_telemetry_profiler.gd
##
## @description
## Entidade matemática responsável por estender as capacidades de telemetria
## do plugin, fornecendo cálculos customizados como o 1% Low de Latência.
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
class_name AdvancedTelemetryProfiler
extends RefCounted

var _window_size: int
var _samples: Array[float] = []


func _init(window_size: int = 100) -> void:
	_window_size = window_size


func push_rtt(rtt_ms: float) -> void:
	_samples.append(rtt_ms)
	if _samples.size() > _window_size:
		_samples.pop_front()


func get_1_percent_low_rtt() -> float:
	if _samples.is_empty():
		return 0.0

	var sorted_samples = _samples.duplicate()
	sorted_samples.sort()

	# P99 calculation: O índice 99% da latência.
	var index = ceili(0.99 * sorted_samples.size()) - 1
	if index < 0:
		index = 0
	elif index >= sorted_samples.size():
		index = sorted_samples.size() - 1

	return sorted_samples[index]
