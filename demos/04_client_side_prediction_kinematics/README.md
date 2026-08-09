# Demo 04: Client-Side Prediction (Kinematics)

## Visão Geral

Implementa o principal pilar da responsividade em jogos multiplayer. Esta demo garante que o jogador local possa movimentar seu avatar com Zero Input Lag, aplicando fisicamente a caminhada na tela instantaneamente antes mesmo que o servidor tenha ciência do input.

## Como Funciona

O domínio isola a matemática de movimento através do `PlayerKinematics` e a repassa ao `MoveLocalPlayerUseCase`. O processamento das teclas direcionais (WASD) é resolvido de forma estática no cliente, alterando a malha visual na hora e, ato contínuo, as coordenadas absolutas resultantes são despachadas via pacote não-confiável (`submit_state`) para atualização do servidor.

## Desafios e Soluções (Clean Architecture)

- **Stuttering Local:** O desafio era evitar que a latência (RTT) interrompesse a marcha do jogador. Vencemos isso desacoplando totalmente a renderização visual do cliente da dependência de respostas do servidor, validando a consistência dos vetores de velocidade direcional através de uma suíte de testes unitários (TDD).

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
