# Changelog (Infraestrutura)

Este documento registra apenas a concepção arquitetural inicial deste repositório matriz. **Ele não será mais mantido para atualizações cotidianas.**

## [1.0.0] - Scaffolding Concluído

### Added

- Inicialização do ambiente das demos com dependência estrita do plugin autoritativo.
- Submódulo git de infraestrutura (`addons/quantic_net`).
- Scripts mágicos de `.vscode/` para reconhecimento em tempo real da "aba ativa" (Active File) para injetar o contexto de comandos do Godot LSP e GUT.
- Script genérico em PowerShell (`setup_demos.ps1`) para automatização e vinculação (*Directory Junctions*) sem repetição de código.
