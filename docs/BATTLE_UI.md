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
- **Alvos:** somente o adaptador da terceira geração expõe `targets`; o painel mostra os battlers presentes nessa lista, diferencia o combatente ativo, o aliado e os adversários e exibe uma barra compacta de HP nos cartões quando os valores públicos de HP atual/máximo são válidos. Dados ausentes ou inválidos não geram estimativas. A barra é apenas informativa: a seleção e o envio continuam usando o ID nativo, sem confundi-lo com o índice visual da grade. Se a lista muda durante a mesma fase, o cursor tenta manter o mesmo ID; se o alvo desaparece, acompanha o alvo nativo atual ou limita a seleção a um índice válido.
- **Batalhas duplas:** quando `double=true`, a faixa do painel identifica o Pokémon que está escolhendo o comando. Quando a API pública também fornece HP atual e máximo válidos, a faixa mostra os valores e uma barra compacta de vida; dados ausentes ou inválidos não geram valores estimados e mantêm o cabeçalho simples. O campo `active` da API pública aponta o slot do jogador (0 ou 2); os cartões classificam os alvos por `side` e comparam o ID nativo ao slot ativo. A fase `party` continua nativa: a API não oferece uma intenção pública para alternar manualmente o combatente ativo dentro do painel customizado.
- **Mudanças de fase, revisão e toque:** cada evento de entrada fica vinculado ao prompt e à revisão do snapshot que o capturaram. Antes da submissão, um novo snapshot precisa manter os dois valores idênticos e ainda aceitar a intenção; se o motor avançou para animação, mensagem, equipe, outro prompt ou uma nova revisão da mesma fase, a entrada antiga é descartada. O painel também marca a geometria de toque com o prompt/revisão que a desenhou; um toque recebido antes do próximo redesenho é consumido sem ativar cartões antigos.
- **Alvos rejeitados pelo motor:** a lista pública de `targets` não descreve todas as regras específicas do golpe. Quando a API nativa rejeita o próprio usuário como alvo, o painel mostra o motivo localizado em inglês, português brasileiro ou espanhol; outras rejeições recebem um aviso genérico. O aviso desaparece após alguns instantes ou quando o estado da batalha muda. A interface não substitui nem tenta prever as regras do jogo. A interface não deduz categorias de alvo pelo tipo do golpe: a API pública fornece IDs dos battlers presentes, mas não expõe uma taxonomia completa de alvos permitidos; a validação final continua pertencendo ao motor.
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

O contrato tem diferenças entre gerações: Gen 1 usa `curMoves` e `moveSelect`, além de expor os prompts `mimic` e `safari`; Gen 2 usa `moves` e `moves`; Gen 3 preserva o slot original de cada golpe, identifica o combatente ativo em batalhas duplas e pode expor IDs de battler não contíguos na seleção de alvo. A fachada pública `UnifiedBattle` normaliza PP ausente para zero, então o painel apresenta `PP 0/0` e bloqueia essa escolha conforme o contrato que realmente chega ao mod. O harness exercita essas diferenças com snapshots sintéticos, incluindo Mimic, Safari, PP normalizada, slot não sequencial, alvos esparsos, papéis dos battlers, mudança do slot ativo, atualização da lista de alvos dentro da mesma fase, descarte de confirmações com prompt/revisão antigos, toque em layout obsoleto, rejeição de alvo próprio e de comandos genéricos, expiração dos avisos e recuperação ao escolher outro alvo.
