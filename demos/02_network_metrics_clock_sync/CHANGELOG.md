# Changelog

Todas as mudancas notaveis para esta demo serao documentadas neste arquivo.

## [1.0.0] - Implementação de Diagnósticos de Rede e Sincronização

### Added

- Extração em tempo real das métricas vitais da Engine C++ (Ping/Jitter/Loss).
- Domínio matemático para agregação em janela deslizante (Sliding Window) para identificar 1% Low de oscilação de quadros e de rede (TDD).
- Overlay Visual (HUD) simulado via GDScript puramente focado em debug.
