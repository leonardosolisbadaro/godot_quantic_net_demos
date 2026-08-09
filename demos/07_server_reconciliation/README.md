# Demo 07: Server Reconciliation

## Visão Geral

Expandindo a punição agressiva da Demo 06, esta iteração implementa a elegância do Server Reconciliation (Reconciliação). O objetivo é garantir que o jogador honesto que sofra uma correção de Snapback devido a atrasos normais na rede não perca totalmente sua fluidez de movimento local.

## Como Funciona

Quando o cliente recebe um pacote de correção forçada (Snapback), em vez de simplesmente teletransportar e ficar paralisado, a lógica de Replay Client-Side (Client Replay) é ativada. O cliente re-aplica (re-simula) de imediato todos os inputs pendentes locais (em frações de milissegundos) que o servidor ainda não havia processado até aquele timestamp.

## Desafios e Soluções (Clean Architecture)

- **Preservação de Inputs (Rubberbanding):** Snapbacks puros causavam "efeito elástico" brutal na tela de quem só estava enfrentando um pico de latência. Isolar a fila de processamento cinemático permitiu que os Use Cases da aplicação reescrevessem o histórico preditivo do jogador silenciosamente, mascarando a correção brutal do C++ debaixo de uma experiência quase impecável.

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
