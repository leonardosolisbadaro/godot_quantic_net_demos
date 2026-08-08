# Changelog - Demo 08

Todas as mudanças e conquistas arquiteturais desta demo estão documentadas aqui.

## [1.0.0] - 2026-08-08

### Added

- Validador Autoritativo de Inputs Customizado (`qn_input_validator.gd`).
- Algoritmo de Tolerância Elástica (Jitter Tolerance) para absorver flutuação no Timestamp de rede.
- Lógica de "Step Capping" que bloqueia matematicamente tentativas de Speedhack/Teleport pelo cliente.
- Re-inclusão do Snapshot Interpolation Visual para suportar pacotes desordenados no _process.
