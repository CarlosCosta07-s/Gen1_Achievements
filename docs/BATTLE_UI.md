# Menu de batalha

## Direção visual

O menu de batalha é a única interface refeita integralmente pelo mod. A referência é a hierarquia de leitura de Pokémon Black/White:
- bandeja inferior escura, separada da HUD superior;
- cartões claros de ação com contraste forte;
- quatro ações principais em uma grade compacta;
- seleção de golpes em quatro espaços;
- tipo do golpe e PP visíveis no próprio cartão;
- seleção de alvos nos combates duplos que expõem essa escolha.

A implementação usa primitivas vetoriais do próprio renderizador. Não inclui sprites, arte, fontes, sons ou outros recursos extraídos de Black/White. O desenho e os componentes são originais.

## Variações por jogo

A composição e o fluxo de comandos são compartilhados. Cada título usa uma cor de destaque e acabamento de borda próprios:

| Jogo | Identidade cromática |
| --- | --- |
| Pokémon Red | Vermelho |
| Pokémon Blue | Azul |
| Pokémon Yellow | Amarelo |
| Pokémon Gold | Dourado |
| Pokémon Silver | Prateado |
| Pokémon Crystal | Ciano |
| Pokémon FireRed | Vermelho quente |
| Pokémon LeafGreen | Verde |
| Pokémon Ruby | Rubi |
| Pokémon Sapphire | Azul safira |
| Pokémon Emerald | Verde esmeralda |

As versões também diferem no acabamento das bordas conforme a geração. O restante da interface do jogo conserva o visual nativo. As cores dos tipos dos golpes são semânticas e permanecem consistentes entre jogos.

## Fluxo funcional

- **Ações:** Fight, Bag, Pokémon e Run são enviadas como escolhas `menu`.
- **Golpes:** quatro cartões exibem nome, tipo e PP; golpes desabilitados ou sem PP não podem ser confirmados.
- **Alvos:** quando a API fornece `targets`, o painel mostra os battlers selecionáveis e envia o ID nativo do alvo.
- **Voltar:** B envia a intenção `back` para sair da seleção de golpe/alvo.
- **Bag e Pokémon:** continuam abrindo os menus nativos da geração. O mod não reimplementa uso de item, captura, troca ou troca forçada.

As escolhas usam o snapshot atual, sua revisão e um ID crescente de intenção via `mod.battle:snapshot()` e `mod.battle:submit()`. O mod não altera HP, PP, turnos, saves ou estado de batalha.

## Controles

- D-pad / setas: mover a seleção.
- A / Enter / Espaço: confirmar.
- B / X / Backspace: voltar da seleção de golpes ou alvos.
- Analógico: mover a seleção quando cruza a zona morta.
- Toque: tocar em um cartão dentro do painel quando o evento não tiver sido capturado pelos controles virtuais do jogo.

O painel captura entrada somente enquanto uma fase controlável (`menu`, `moves`, `target`) está ativa. Outras fases, mensagens, animações e menus nativos continuam sob controle do jogo. No Android, os controles virtuais nativos também podem navegar e confirmar o menu.

## Compatibilidade

O painel inferior nativo é ocultado por `battle.bottom_ui_visible` nas versões que expõem esse hook. Em versões sem esse ponto de extensão, o painel vetorial cobre a região inferior em `render.hud` sem substituir a HUD superior. O motor continua sendo a autoridade sobre as regras e a execução das escolhas.

O harness verifica esse fluxo usando snapshots sintéticos. A confirmação final exige testes visuais e de comandos nas onze versões executáveis.
