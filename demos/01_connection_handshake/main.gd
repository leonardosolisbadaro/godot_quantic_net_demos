extends Node

var is_server_mode: bool = false
var qn: Node = null
var last_pong_print: float = 0.0

func _ready() -> void:
	print("========================================")
	print(">>> 01_CONNECTION_HANDSHAKE INICIADA <<<")
	print("========================================")
	
	qn = get_node_or_null("/root/QuanticNet")
	if not qn:
		print("[ERRO FATAL] Autoload QuanticNet não encontrado!")
		return
	
	# 1. Mapeamento de Sinais da API Pública
	qn.connect("connection_state_changed", Callable(self, "_on_state_changed"))
	qn.connect("peer_joined", Callable(self, "_on_peer_joined"))
	qn.connect("peer_left", Callable(self, "_on_peer_left"))
	qn.connect("pong_received", Callable(self, "_on_pong_received"))
	
	# 2. Resolução do Contexto (CLI Args)
	var args = OS.get_cmdline_user_args()
	if "--server" in args:
		is_server_mode = true
		_log("Inicializando modo SERVIDOR (Autoritativo)...")
		var err = qn.host(8080, "secret")
		if err == OK:
			_log("Bind concluído. Aguardando peers na porta 8080...")
		else:
			_log("Falha crítica ao subir Host! Código Godot: " + str(err))
			
	elif "--client" in args:
		is_server_mode = false
		_log("Inicializando modo CLIENTE...")
		var err = qn.join("127.0.0.1", 8080, "secret")
		if err == OK:
			_log("Tentativa de socket DTLS disparada para 127.0.0.1:8080")
		else:
			_log("Falha crítica ao iniciar Cliente! Código Godot: " + str(err))

# --- Utils de Log ---
func _log(msg: String) -> void:
	var prefix = "[SERVER]" if is_server_mode else "[CLIENT]"
	print("%s %s" % [prefix, msg])

# --- Callbacks da Máquina de Estados ---
func _on_state_changed(new_state: int) -> void:
	var state_name = "DESCONHECIDO"
	if qn:
		match new_state:
			qn.ConnectionState.DISCONNECTED: state_name = "DISCONNECTED"
			qn.ConnectionState.CONNECTING: state_name = "CONNECTING (Handshake Socket)"
			qn.ConnectionState.AUTHENTICATING: state_name = "AUTHENTICATING (Validando Identidade/Secret)"
			qn.ConnectionState.CONNECTED: state_name = "CONNECTED (Sessão Estabelecida)"
			qn.ConnectionState.FAILED: state_name = "FAILED (Falha Crítica)"
		
	_log("State Transition -> " + state_name)

func _on_peer_joined(id: int) -> void:
	_log("Peer Autenticado e Registrado Oficialmente: ID " + str(id))

func _on_peer_left(id: int) -> void:
	_log("Peer Removido da Topologia: ID " + str(id))

func _on_pong_received(rtt_ms: float, offset_ms: float) -> void:
	# Throttling de prints do PING para não floodar o terminal
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_pong_print > 2.0:
		last_pong_print = now
		_log("Telemetria Viva -> RTT (Ping): %.1f ms | Offset de Relógio: %.1f ms" % [rtt_ms, offset_ms])

# --- Cleanup Gracioso ---
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_log("Sinal de fechamento interceptado. Expurgação higiênica ativada...")
		if qn:
			qn.disconnect_net(true)
