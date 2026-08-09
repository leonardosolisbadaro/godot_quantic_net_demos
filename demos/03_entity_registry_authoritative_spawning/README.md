# Demo 03: Entity Registry & Authoritative Spawning

## Visão Geral

A introdução definitiva à topologia de "Mundo 3D". Esta demo ilustra como o Servidor registra autoritativamente as entidades ativas do mapa (Avatares e Props) e controla de forma estrita a taxa de atualização (Tickrate/QoS) de envio pela rede de cada uma delas.

## Como Funciona

Utilizando a `EntityProfileFactory` e seus respectivos Casos de Uso, o servidor cadastra entidades com configurações distintas: Jogadores transmitem estado a 60Hz, enquanto Props de cenário economizam banda a 5Hz. Os clientes adotam uma postura de renderização Zero-RPC, desenhando os avatares alheios de forma otimista baseando-se apenas nos estados silenciosos injetados na malha pelo Gateway C++.

## Desafios e Soluções (Clean Architecture)

- **Tráfego Desnecessário (Bandwidth):** Atualizar objetos estáticos na mesma frequência que os players causaria asfixia de rede. A solução foi aplicar regras de QoS isoladas (via TDD) que estipulam perfeitamente a prioridade de empacotamento no C++, otimizando o fluxo de dados em larga escala.

---

## Como Executar

Para rodar esta demo de forma isolada (1 Servidor, 2 Clientes + Simulação Netem), utilize o script auxiliar no Windows:

```powershell
powershell.exe -ExecutionPolicy Bypass -File toggle_demo.ps1
```

> **Nota:** Basta rodar novamente para derrubar as instâncias e fechar o teste.
