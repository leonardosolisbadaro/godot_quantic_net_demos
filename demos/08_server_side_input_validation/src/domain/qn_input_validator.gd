## @file qn_input_validator.gd
## @path res://src/domain/qn_input_validator.gd
##
## @description
## Validador autoritativo baseado em Inputs (Server-Side Deterministic Simulation).
## Ignora a posição enviada pelo cliente caso destoe da simulação matemática feita no servidor
## com base nos inputs (rot) fornecidos.
##
## @created 2026-08-08
## @updated 2026-08-08
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)

signal peer_rejected(id: int, reason: String, strikes: int)

var PlayerKinematics = preload("res://src/domain/player_kinematics.gd")
var speed := 10.0
var max_strikes := 5

class PeerState:
	var pos: Vector3
	var rot: Vector3
	var last_ts: int
	var strikes: int = 0
	var seq: int = 0

var peers := {}

func configure(config: Dictionary) -> void:
	max_strikes = config.get("max_strikes", 5)

func peer_left(id: int) -> void:
	peers.erase(id)

func validate(id: int, client_pos: Vector3, rot: Vector3, now: int) -> Dictionary:
	if not peers.has(id):
		var st := PeerState.new()
		st.pos = client_pos
		st.rot = rot
		st.last_ts = now
		peers[id] = st
		peers[id].seq = 0
		return {"action": "accept", "pos": client_pos, "rot": rot}
	var st: PeerState = peers[id]
	var dt: float = float(now - st.last_ts) / 1000.0
	if dt <= 0.0:
		dt = 0.001
		
	# Usamos uma janela de tempo efetiva para evitar que o cliente forje timestamps absurdos (teleport)
	# e para suavizar frames onde o clock_offset flutua violentamente por causa do NETEM.
	var effective_dt = minf(maxf(dt, 0.05), 0.2)
	
	var move_vec = client_pos - st.pos
	var attempted_step = move_vec.length()
	var max_step = speed * effective_dt
	
	var server_pos: Vector3
	
	# O limite mágico: como não temos um Jitter Buffer C++ rodando a ticks fixos de 20Hz,
	# as chegadas dos pacotes são assíncronas. Uma tolerância elástica é OBRIGATÓRIA.
	var jitter_tolerance = speed * 0.1 # Ex: 1.0 metro de flexibilidade
	
	if attempted_step <= max_step + jitter_tolerance:
		# Accept: O movimento está dentro da capacidade cinemática do avatar.
		# Ao invés de forçar a matemática pura, aceitamos a correção do cliente para evitar stuttering nos outros peers.
		server_pos = client_pos
	else:
		# Reject Parcial: Cliente excedeu a velocidade máxima permitida + tolerância.
		# Capamos o vetor na velocidade máxima da engine.
		var input_dir = Vector3.ZERO
		if attempted_step > 0.0001:
			input_dir = move_vec.normalized()
		server_pos = st.pos + input_dir * max_step
	
	var dist = client_pos.distance_to(server_pos)
	if dist <= 0.2:
		st.pos = server_pos
		st.rot = rot
		st.last_ts = now
		st.strikes = maxi(0, st.strikes - 1)
		return {"action": "accept", "pos": server_pos, "rot": rot}
		
	# Reject Total (Cheat)
	st.strikes += 1
	peer_rejected.emit(id, "Desvio de simulação: %.2fm (Input Validation Falhou)" % dist, st.strikes)
	
	st.last_ts = now
	return {"action": "reject", "pos": st.pos, "rot": rot, "strikes": st.strikes}

func should_kick(id: int) -> bool:
	return peers.has(id) and peers[id].strikes >= max_strikes
