# Changelog

Todas as mudancas notaveis para esta demo serao documentadas neste arquivo.

## [1.0.0] - Implementação de Cinemática Local e CSP

### Added

- Configurações globais de rede repassadas no Host/Join para suportar simulação via Netem.
- `PlayerKinematics`: Domínio matemático puro (TDD) para controle direcional WASD e velocidade com delta time.
- `MoveLocalPlayerUseCase`: Orquestração instantânea visual que blinda a engine C++ através de injeção UDP (`submit_state`).
- Atualização limpa da suíte de testes (GUT) restrita apenas à lógica introduzida por esta demo (Responsividade e Anti-Speedhack).
