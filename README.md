# QuanticNet Demos (Godot 4.7)

Este repositório atua como o laboratório oficial (um *monorepo* ou "condomínio") para a criação de instâncias competitivas e validações focadas no plugin **QuanticNet** (Netcode Autoritativo C++ para MMOs 3D).

A arquitetura deste repositório foi construída para suportar dezenas de demos isoladas, mantendo o ambiente limpo, sem duplicação de dependências e altamente integrado ao VSCode.

## Estrutura do Repositório

- `/addons/quantic_net`: O plugin QuanticNet importado via **Git Submodule**. Este é o código fonte mestre, e nenhuma demo altera esse diretório.
- `/demos/`: Diretório matriz contendo todas as provas de conceito. Cada subdiretório aqui (ex: `01_connection_handshake`) é um projeto Godot 100% independente.
- `.vscode/scripts/`: Scripts mágicos em PowerShell que identificam a "aba ativa" no editor para rodar comandos injetando o caminho correto da demo ativa em tempo real.

## Como criar uma nova Demo?

Para evitar tarefas repetitivas, possuímos um script gerador de estrutura básica (*scaffolding*).

Abra o terminal na raiz do projeto e execute:

```powershell
.\setup_demos.ps1 -n [nome_da_demo]
```

Por exemplo:

```powershell
.\setup_demos.ps1 -n 04_client_side_prediction_kinematics
```

### Demos Implementadas (Até agora)

- **01 Handshake State Machine:** Ciclo de vida e conexão básica.
- **02 Network Metrics Clock Sync:** Extração de RTT, Jitter, e 1% Low de oscilação.
- **03 Entity Registry Authoritative Spawning:** Sincronização Server-Client de props e avatars sem mistura de RPC.

**O que o script faz?**

1. Cria a pasta da demo base com os arquivos essenciais (`project.godot`, `main.gd`, `main.tscn`, `TODO.md`, `CHANGELOG.md`).
2. Gera automaticamente uma **Directory Junction** (`mklink /J`) dentro da demo apontando para o submódulo da raiz, garantindo que todas as demos consumam o mesmo plugin fisicamente sem duplicar arquivos na memória.
3. Roda a Godot silenciosamente em *headless mode* (`--editor`) para compilar o cache (`.godot/`) e registrar a *GDExtension* C++ imediatamente.

> *Dica: Após rodar o script, você pode renomear livremente a pasta recém-criada para o nome que desejar.*

## Atalhos do VSCode (Context-Aware)

A integração com o VSCode neste projeto é contextualmente inteligente. Ao apertar um atalho, nossos scripts varrem a árvore de arquivos de baixo para cima a partir da guia (Active Tab) que você estiver visualizando, encontram o `project.godot` e executam a ação **restrita àquela demo**.

| Tecla | Ação | Descrição |
| :--- | :--- | :--- |
| **F5** | Run Default Scene | Abre a Godot UI normalmente, executando a demo atual. |
| **F10** | Kill Godot Processes | Varre o WMI do Windows e derruba rigorosamente todos os processos fantasmas da Godot. |
| **F11** | Toggle Demo | Simulação de Rede Rápida: Abre 1 Servidor e 2 Clientes em instâncias de terminal (Console/Headless). Se já estiverem abertos, aperta F11 novamente para encerá-los limpos. |
| **F12** | Run GUT Tests | Dispara o framework de testes unitários (GUT) restrito à demo atual. |

## Regras e Tratados de Arquitetura

O desenvolvimento de código dentro das demos segue diretrizes inegociáveis. Para conhecer as restrições (*Code-First*, Isolamento de Domínio, *Clean Architecture*, TDD), leia a constituição absoluta do repositório:
👉 [GEMINI.md](GEMINI.md)
