## @file test_advanced_telemetry_profiler.gd
## @path res://tests/test_advanced_telemetry_profiler.gd
##
## @description
## Testes unitários para o cálculo estatístico do 1% Low (99th Percentile)
## de RTT (Ping).
##
## @created 2026-08-07
## @updated 2026-08-07
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

extends GutTest

const AdvancedTelemetryProfiler = preload("res://src/domain/advanced_telemetry_profiler.gd")

var _sut: AdvancedTelemetryProfiler

func before_each() -> void:
	_sut = AdvancedTelemetryProfiler.new(100) # Janela de 100 amostras

func after_each() -> void:
	_sut = null

func test_deve_retornar_zero_quando_vazio() -> void:
	assert_eq(_sut.get_1_percent_low_rtt(), 0.0, "Profiler vazio deve retornar 0")

func test_deve_calcular_o_99th_percentile_corretamente() -> void:
	# Arrange: insere pings de 1 a 100 em ordem aleatória (ou inversa)
	var amostras = []
	for i in range(1, 101):
		amostras.append(float(i))
	
	# Embaralha só para ter certeza que o SUT não depende de ordem de inserção
	amostras.shuffle()
	
	# Act
	for v in amostras:
		_sut.push_rtt(v)
	
	var rtt_1_low = _sut.get_1_percent_low_rtt()
	
	# Assert
	# O 99º percentil de [1..100] é 99 (ou 100 dependendo da fórmula matemática de interpolação).
	# Usando o método de índice simples: index = ceil(0.99 * 100) - 1 = 98 (que é o valor 99).
	# Vamos aceitar 99.0
	assert_eq(rtt_1_low, 99.0, "O 1% Low de latência de amostras [1..100] deve ser 99.0")

func test_janela_deslizante_deve_descartar_valores_antigos() -> void:
	# Enche a janela de 100 com o valor "10"
	for i in range(100):
		_sut.push_rtt(10.0)
		
	# Empurra mais 100 valores "500"
	for i in range(100):
		_sut.push_rtt(500.0)
		
	# A janela só deve conter os 500s agora. O 99% de 500s é 500.
	assert_eq(_sut.get_1_percent_low_rtt(), 500.0, "Valores antigos devem ser ignorados pela janela deslizante")
