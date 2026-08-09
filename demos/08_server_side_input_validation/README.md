# Demo 08: Server-Side Input Validation

## Visão Geral

A demo definitiva de arquitetura e-sports. O paradigma evolui de correções puramente posicionais para simulação estrita baseada em Inputs (Teclas). O servidor toma controle granular sobre a validação das intenções de controle dos usuários antes de convertê-las em movimento válido, barrando qualquer forma de teleporte ou aceleração induzida via memória.

## Como Funciona

O QuanticNet é injetado com um validador nativo GDScript (`qn_input_validator.gd`). O fluxo de movimentos passa por um buffer autoritativo de Jitter Tolerance (Tolerância Elástica), e regras absolutas como "Step Capping" (Limite rígido por delta). O servidor reconstrói e repassa perfeitamente as rotas sob latências de 150ms sem perder coesão.

## Desafios e Soluções (Clean Architecture)

- **Tolerância a Flutuações (Falsos Positivos):** Simulações estritas em cima de Input causam punições falsas facilmente porque pacotes de rede enfileiram. Vencemos a turbulência arquitetando tolerância elástica dentro do loop preditivo, garantindo que "rajadas" de pacotes sejam validadas em segurança sem estourar o cap de passos.

> **💡 Nota Arquitetural (Dual Paradigm):** O QuanticNet suporta duas formas de simulação. Nesta Demo 08, optamos por manter a fundação no **Paradigma State-Based** (onde o cliente envia estados e inputs embutidos) para provar a extrema flexibilidade do plugin, demonstrando que é possível blindar até mesmo arquiteturas ágeis e preditivas sem reescrever o cliente. No entanto, para cenários e-sports puristas, a implementação mais eficiente e inviolável é o **Paradigma Command-Based** (onde o cliente é estúpido e envia apenas Inputs brutos), o qual é o foco da **Demo 09: Command-Based Architecture**.

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
