# Changelog (Infraestrutura)

Este documento registra apenas a concepção arquitetural inicial deste repositório matriz. **Ele não será mais mantido para atualizações cotidianas.**

## [1.1.0] - Implementação de Demos Base & Script Avançado

### Added

- Demo `01_handshake_state_machine`: Protocolo de Handshake e ciclo de vida sob Clean Architecture.
- Demo `02_network_metrics_clock_sync`: Telemetria, RTT, Loss, e cálculos estatísticos (1% Low).
- Demo `03_entity_registry_authoritative_spawning`: Registro Autoritativo, Perfis de Rede (QoS) e Client-Side Rendering local.
- O script `setup_demos.ps1` agora aceita argumentos com nomes específicos para instanciar demos baseados em template parametrizado.

- Inicialização do ambiente das demos com dependência estrita do plugin autoritativo.
- Submódulo git de infraestrutura (`addons/quantic_net`).
- Scripts mágicos de `.vscode/` para reconhecimento em tempo real da "aba ativa" (Active File) para injetar o contexto de comandos do Godot LSP e GUT.
- Script genérico em PowerShell (`setup_demos.ps1`) para automatização e vinculação (*Directory Junctions*) sem repetição de código.
