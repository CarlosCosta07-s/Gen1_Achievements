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
- **Golpes:** até quatro cartões exibem nome, tipo e PP. Golpes desabilitados ou com PP igual a zero não podem ser confirmados.
- **Mimic (Gen 1):** a lista nativa de golpes copiáveis é exibida no mesmo painel; a seleção envia o índice nativo `mimic` sem alterar diretamente o golpe do Pokémon.
- **Safari Zone (Gen 1):** o painel apresenta Ball, Bait, Rock e Run, além da quantidade restante de bolas. Todas as ações ficam desabilitadas quando não há bolas disponíveis.
- **Legibilidade:** os textos dos cartões são escalados proporcionalmente à largura disponível, preservando nomes e tipos longos (como Electric e Fighting) sem colidir com o indicador de PP.
- **Alvos:** somente o adaptador da terceira geração expõe `targets`; o painel mostra os battlers disponíveis e envia o ID nativo, sem confundir IDs esparsos com a posição visual do cartão.
- **Voltar:** B envia a intenção `back` para sair da seleção de golpe/alvo. Mimic e Safari não expõem uma intenção pública de cancelamento; o menu não inventa uma ação de retorno.
- **Bag e Pokémon:** continuam abrindo os menus nativos da geração. O mod não reimplementa uso de item, captura, troca ou troca forçada.

As escolhas usam o snapshot atual, sua revisão e um ID crescente de intenção via `mod.battle:snapshot()` e `mod.battle:submit()`. O mod não altera HP, PP, turnos, saves ou estado de batalha.

## Controles

- D-pad / setas: mover a seleção.
- A / Enter / Espaço: confirmar.
- B / X / Backspace: voltar da seleção de golpes ou alvos.
- Analógico: mover a seleção quando cruza a zona morta.
- Controles virtuais Android/iOS: D-pad e A/B também navegam pelo mesmo menu, sem deixar a entrada chegar à tela nativa oculta.
- Toque direto: tocar em um cartão confirma a ação; tocar na indicação `B: VOLTAR` na seleção de golpes/alvos retorna à etapa anterior. As coordenadas são transformadas para o espaço lógico, inclusive com janela ampliada, letterboxing ou viewport deslocado.

O painel captura entrada somente enquanto uma fase controlável (`menu`, `moves`, `target`, `mimic` ou `safari`) está ativa. O hook `input.step` observa as bordas do overlay virtual antes de o motor promover os botões. A captura também registra `overlayPressed`, então um toque rápido que começa e termina entre passos não é perdido; a máscara temporária impede que o menu nativo consuma a mesma borda. Seleção forçada de equipe (`party`), avanço de mensagens (`advance`), fases bloqueadas, batalhas Link e batalhas de tutorial permanecem sob controle do jogo. Ao sair de uma fase substituída, o mod restaura os métodos originais de entrada e torna a camada inferior nativa visível novamente. No Android, os controles virtuais nativos também podem navegar e confirmar o menu.

## Compatibilidade

O painel inferior nativo é ocultado por `battle.bottom_ui_visible` nas versões que expõem esse hook. Em versões sem esse ponto de extensão, o painel vetorial cobre a região inferior em `render.hud` sem substituir a HUD superior. O motor continua sendo a autoridade sobre as regras e a execução das escolhas.

O contrato tem diferenças entre gerações: Gen 1 usa `curMoves` e `moveSelect`, além de expor os prompts `mimic` e `safari`; Gen 2 usa `moves` e `moves`; Gen 3 preserva o slot original de cada golpe e pode expor IDs de battler não contíguos na seleção de alvo. A fachada pública `UnifiedBattle` normaliza PP ausente para zero, então o painel apresenta `PP 0/0` e bloqueia essa escolha conforme o contrato que realmente chega ao mod. O harness exercita essas diferenças com snapshots sintéticos, incluindo Mimic, Safari, PP normalizada, slot não sequencial, alvo esparso e transição para telas nativas.
