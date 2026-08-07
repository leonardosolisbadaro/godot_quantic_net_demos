# TODO: 01_connection_handshake

O escopo desta demo é **estritamente validar e auditar a fundação da rede**. Nenhuma mecânica de jogo (Grid, Movimento, etc.) será inserida aqui. O foco é garantir que o plugin consegue estabelecer a topologia Client-Server de forma estável e que conseguimos monitorar isso.

## Fase 1: Network Event Hooks & Verbose Logging

- [x] Mapear todos os sinais de conexão e estado expostos pela API Pública do QuanticNet.
- [x] Conectar callbacks no `main.gd` para escutar e emitir logs detalhados (*verbose*) de todo o processo de handshake.
- [x] Diferenciar de forma clara e visual os logs do Servidor (ex: `[SERVER] Peer Connected: ID X`) dos logs do Cliente (`[CLIENT] Authenticated`).
- [x] Validar desconexões graciosas (quando fechamos os processos).
