# GEMINI.md - A Constituição Arquitetural (Demos & MMO)

## Preâmbulo

Este documento é a **constituição absoluta e soberana** deste repositório de Demos e do futuro 3D Open World MMO. As regras, diretrizes, padrões e fluxos aqui descritos orientam de forma estrita o comportamento da Inteligência Artificial (IA) e de qualquer desenvolvedor humano que interaja com esta base de código.

O objetivo deste documento é **garantir a evolução controlada, limpa, testável e segura** do ecossistema de jogo, servindo como a única fonte da verdade para decisões arquiteturais. A IA está terminantemente proibida de afrouxar estas regras sob qualquer pretexto.

## 1. O PROTOCOLO GEMINI (Fluxo de Trabalho Obrigatório)

Para garantir que não haja alterações destrutivas, aumento de acoplamento ou erosão arquitetural sem supervisão rigorosa, a IA deve operar **estritamente** no seguinte ciclo de 3 passos:

1. **Passo 1: Análise e Plano de Ação:** Ao receber uma demanda, a IA deve mapear o contexto completo do projeto (`TODO.md`, dependências afetadas). A IA deve responder **apenas** com um Plano de Ação detalhado, explicitando claramente quais camadas serão afetadas e quais ficheiros serão criados/modificados.
2. **Passo 2: Refinamento:** Se houver qualquer ambiguidade (técnica ou de regras de negócio), a IA é obrigada a fazer questionamentos pontuais antes de gerar qualquer código.
3. **Passo 3: Execução Bloqueada:** A IA gerará o código final **APENAS** após o utilizador responder explicitamente com "Aprovado" ou "Pode avançar" ao Plano de Ação.

## 2. RESTRIÇÕES FUNDAMENTAIS E LIMITES INTRANSPONÍVEIS

A IA está **terminantemente proibida** de:

- **Vazar Lógica para o Plugin:** Nenhuma lógica de jogo pode ser inserida dentro do submódulo `addons/quantic_net`. O plugin é uma **caixa preta** agnóstica de rede e deve ser consumido apenas via Autoload ou sua API Pública.
- **Acoplamento Visual (UI-Bound Logic):** Injetar lógica de domínio, regras de jogo ou chamadas de rede diretamente em scripts anexados a nós visuais (`.tscn`). A camada de apresentação (Mesh, Sprites, UI) atua estritamente como *visualizadora* do estado.
- **Dependências Globais Ocultas:** Utilizar `AutoLoads` (Singletons) nativos da Godot para compartilhar estado de jogo ou injetar dependências (com exceção do próprio plugin QuanticNet, se aplicável como Autoload de infraestrutura). Toda injeção no domínio deve ser explícita.
- **Uso Indiscriminado de `class_name`:** O uso global de classes polui o namespace e corrompe o cache. Utilize `preload` com caminhos absolutos (`res://`) para carregar dependências.
- **Alucinação de APIs da Engine:** Empregar funções ou abordagens sem certeza absoluta, especialmente na Godot 4.7. Consulte a documentação oficial.

## 3. ARQUITETURA E LIMITES DE CAMADAS (Clean Architecture)

A aplicação (o Jogo/MMO) segue uma Clean Architecture adaptada ao ecossistema da Godot Engine. A regra da dependência é **unidirecional e de cima para baixo**.

### 3.1. A Topologia do Jogo (Ordem de Dependência)

Para suportar instâncias competitivas e um MMO com autoridade central, a arquitetura do jogo divide-se nas seguintes camadas (de dentro para fora):

1. **Core Domain (`src/domain/`):** O coração do jogo. Contém as regras de negócio puras (ex: `PlayerStats`, `Inventory`, `CombatRules`). Totalmente agnóstico à Engine e à Rede.
2. **Use Cases (`src/use_cases/`):** Orquestram o fluxo de ações dos jogadores (ex: `MovePlayer`, `UseItem`, `AttackEntity`).
3. **Interface Adapters (`src/adapters/`):** Tradutores de limites. Convertem os dados entre o Domínio/Casos de Uso e a camada externa (Visuais ou Rede).
4. **Framework & Infrastructure (`src/infrastructure/` e `addons/quantic_net/`):** A camada mais externa. É aqui que os nós da Godot operam e onde o **plugin QuanticNet** é consumido como infraestrutura para sincronizar o estado com o servidor via rede.

## 4. O MANDATO DE INFRAESTRUTURA E GODOT 4.7

O projeto é governado por **Code-First** e **Clean Architecture**, eliminando lógicas de negócios presas ao editor da Godot.

- Todo o código deve estar de acordo com os padrões da **Godot 4.7**.
- O **QuanticNet** atua como o motor subjacente. Sincronização de entidades, Spatial Grids e interpolação são delegadas a ele. O jogo apenas interage com a API pública para gerenciar seu estado distribuído.

## 5. O MANDATO DE TESTES (TDD Obrigatório)

O projeto é governado por **TDD Rigoroso**. Nenhuma mecânica nova (movimentação, combate, inventário, etc.) pode ser implementada sem um teste unitário a justificá-la.

### 5.1. As Leis de Ouro do TDD e AAA

1. **Test-First Exigido:** É expressamente proibido escrever código sem antes ter escrito um `.gd` de teste falhando na pasta `tests/`. O ciclo vermelho, verde e refatoração é obrigatório.
2. **Metodologia AAA:** Cada teste unitário deve servir como documentação viva, estruturado rigorosamente em **Arrange (Preparação)**, **Act (Ação)** e **Assert (Verificação)**.
3. **Framework Obrigatório:** O uso do **[bitwes/Gut](https://github.com/bitwes/Gut)** é mandatório.

## 6. PADRÕES DE CÓDIGO E CONVENÇÕES

### 6.1 Cabeçalhos de Arquivos (GDScript Docstrings)

Todo arquivo `.gd` deve iniciar com um bloco de docstrings padronizado:

```gdscript
## @file [nome_do_arquivo.gd]
## @path [caminho/relativo/nome_do_arquivo.gd]
##
## @description
## Descrição clara da responsabilidade arquitetural do arquivo.
## No caso de testes, detalhar o SUT e mocks globais.
##
## @created [YYYY-MM-DD]
## @updated [YYYY-MM-DD]
##
## @author Leonardo S. Badaró (with Gemini 3.1 Pro - High)
```

### 6.2 Formatação e Nomenclatura

- **Identação:** Tabs puros (`\t`), configurados para tamanho visual de 4 espaços.
- **Nomenclatura:** `snake_case` para funções e variáveis (GDScript Style Guide). `PascalCase` para Nodes/Classes.

## 7. DIRETRIZES DE EVOLUÇÃO E INTEGRIDADE

Ao criar uma nova mecânica ou domínio, siga o fluxo em cascata:

1. **Definição de Contratos e TDD:** Escreva o teste que dita o comportamento esperado para o Core Domain.
2. **Ciclo TDD (Domínio):** Implemente o domínio até o teste passar (Verde) e refatorar, sem acoplamento externo.
3. **Casos de Uso e Adaptadores:** Conecte o domínio à infraestrutura através de injeção de dependência via construtor.
4. **Integração Visual e QuanticNet:** Renderize os resultados utilizando nós Godot, e sincronize a rede delegando tarefas ao plugin `quantic_net`.

## 8. Padrões de Documentação e Versionamento (SemVer)

- **SemVer:** O projeto adota `MAJOR.MINOR.PATCH`.
- **Changelog:** Todas as alterações relevantes devem ser documentadas no `CHANGELOG.md`.

**[FIM DO CONTRATO]**
