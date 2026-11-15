# Menu de batalha

## Direção visual

A camada de navegação do mod usa os próprios recursos de interface do jogo selecionado. Ela não tenta dar a todos os títulos a aparência de outro jogo e não desenha cartões vetoriais genéricos por cima da batalha.

O mod resolve em tempo de execução a fonte, as janelas/molduras, o cursor e, quando aplicável, a paleta pertencentes ao perfil ativo do Gen1Recomp. Esses recursos já são carregados pelo motor para o jogo selecionado; o pacote do mod não contém sprites, fontes, molduras, tiles ou outros arquivos extraídos de ROM.

A camada customizada só assume o painel inferior quando consegue resolver os recursos nativos necessários. Se a fonte ou a moldura esperada não estiver disponível, o mod mantém o painel original do motor visível e deixa a batalha seguir pelo caminho nativo. Isso evita esconder a interface do jogo e substituí-la por uma tela vazia.

## Recursos por geração e jogo

| Títulos | Recursos nativos utilizados | Organização |
| --- | --- | --- |
| Red, Blue e Yellow | Fonte de Game Boy, caixas e glifo de cursor do renderizador do Gen1Recomp | Layout 160×144; menu de ações, seletor vertical de golpes e janelas de informação de tipo/PP |
| Gold, Silver e Crystal | Fonte e Chrome de Game Boy Color, incluindo molduras com paleta e cursor | Layout 160×144; composição própria de GBC, mantendo as molduras e cores nativas |
| FireRed e LeafGreen | Fonte do perfil FRLG, molduras de batalha e cursor GBA do motor | Layout 240×160; posições e janelas da família FRLG |
| Ruby e Sapphire | Fonte do perfil Ruby/Sapphire, molduras e cursor específico dessa família | Layout 240×160; posições de ação e golpes próprias de Ruby/Sapphire |
| Emerald | Fonte e janelas do perfil Emerald, molduras de batalha e cursor GBA | Layout 240×160; posições calculadas a partir dos identificadores de janela de Emerald |

A camada usa as APIs de renderização já expostas/carregadas pelo Gen1Recomp: `mod.ui.Font` e `src.ui.gen2.Chrome` nas gerações anteriores; na terceira geração, o perfil da sessão fornece o módulo de fonte e o mod consulta os módulos de `battle_chrome`, `window`, texto e tipos do jogo ativo. Para Ruby/Sapphire, o cursor específico da família é resolvido separadamente.

A aparência de cada jogo vem desses módulos nativos, e não de cores decorativas ou de assets copiados para o repositório. Não há uma tabela de onze temas artificiais.

## Fluxo funcional

- **Ações:** Fight, Bag, Pokémon e Run são enviadas como escolhas `menu`. A ordem acompanha a geração e o título; as posições de texto e cursor seguem a janela nativa.
- **Golpes:** até quatro entradas são desenhadas na área original de seleção. Nome, tipo e PP usam a fonte ativa e a área de informação de cada família. Golpes desabilitados ou com PP igual a zero não podem ser confirmados.
- **Mimic (Gen 1):** a lista de golpes copiáveis usa a janela e a fonte de Game Boy; a seleção envia o índice nativo `mimic`, sem alterar diretamente o golpe do Pokémon.
- **Safari Zone (Gen 1):** Ball, Bait, Rock e Run são apresentados em uma janela do estilo original, junto da contagem restante de bolas. As ações não podem ser confirmadas quando a contagem chega a zero.
- **Tipos:** na terceira geração, os nomes de tipo podem ser resolvidos pelos dados de tipo do jogo e pelo texto nativo disponível. Nas gerações anteriores, os nomes fornecidos pelo snapshot são desenhados na fonte do motor.
- **Alvos:** somente o adaptador que fornece `targets` permite substituir essa fase. A lista usa fonte, moldura e cursor nativos; mostra os battlers presentes no snapshot e, quando válidos, HP numérico, papel e condição reconhecida. O motor não fornece uma matriz completa de elegibilidade por golpe, então o mod não inventa alvos permitidos nem marca battlers como inelegíveis por suposição.
- **Batalhas duplas:** quando `double=true`, o painel identifica o Pokémon que está escolhendo o comando. Se a API fornecer HP atual e máximo válidos, os valores aparecem numericamente; dados ausentes ou inválidos não geram valores estimados. A fase de seleção/troca de equipe continua nativa.
- **Alvos rejeitados:** quando a API nativa rejeita o próprio usuário como alvo, o mod mostra o aviso localizado. Outras rejeições recebem aviso genérico. O aviso expira ou desaparece quando a fase/revisão muda.
- **Bag e Pokémon:** continuam abrindo os menus nativos da geração. O mod não reimplementa o uso de itens, captura, troca ou troca forçada.

As escolhas usam o snapshot atual, sua revisão e um ID crescente de intenção via `mod.battle:snapshot()` e `mod.battle:submit()`. O mod não altera HP, PP, turnos, saves ou estado de batalha.

## Controles

- D-pad / setas: mover o cursor. Nos seletores de golpes de Gen 1/2, a navegação vertical segue a lista original; as grades de ações, alvos e telas GBA mantêm a movimentação correspondente ao layout.
- A / Enter / Espaço: confirmar.
- B / X / Backspace: voltar da seleção de golpes ou alvos, quando a API pública aceita a intenção `back`.
- Analógico: mover o cursor quando cruza a zona morta.
- Controles virtuais Android/iOS: D-pad e A/B navegam pelo mesmo estado de batalha; a borda de toque não é encaminhada também ao painel nativo que foi substituído.
- Toque direto: tocar em uma opção na área desenhada confirma essa escolha. A coordenada é convertida para o espaço lógico da viewport; toques fora da área pertencente ao menu continuam sendo encaminhados ao jogo.

Mimic e Safari não expõem uma intenção pública de cancelamento; o mod não inventa uma ação de retorno nessas fases. O painel captura entrada somente enquanto uma fase controlável (`menu`, `moves`, `target`, `mimic` ou `safari`) está ativa. Cada evento fica vinculado ao prompt e à revisão do snapshot que o capturaram. Se o motor avançar para animação, mensagem, equipe, outro prompt ou uma nova revisão da mesma fase, a entrada antiga é descartada. A geometria de toque também fica vinculada ao prompt/revisão do desenho, para impedir que um toque atrasado ative uma opção antiga.

O hook `input.step` observa as bordas do overlay virtual antes de o motor promover os botões. A captura também registra `overlayPressed`, então um toque rápido que começa e termina entre passos não é perdido; uma máscara temporária impede que o menu nativo consuma a mesma borda. Seleção forçada de equipe (`party`), avanço de mensagens (`advance`), fases bloqueadas, batalhas Link e batalhas de tutorial permanecem sob controle do jogo. Ao sair de uma fase substituída, o mod restaura os métodos originais de entrada e torna a camada inferior nativa visível novamente.

## Compatibilidade e fallback

O hook `battle.bottom_ui_visible` só oculta o painel nativo quando o mod consegue resolver os recursos originais necessários para o jogo ativo. Se o hook não existir ou os módulos/artefatos não estiverem disponíveis, o jogo conserva a sua própria interface; o mod não desenha cartões genéricos como substituto.

O contrato tem diferenças entre gerações: Gen 1 usa `curMoves` e `moveSelect`, além de expor os prompts `mimic` e `safari`; Gen 2 usa `moves`; Gen 3 preserva o slot original de cada golpe, identifica o combatente ativo em batalhas duplas e pode expor IDs de battler não contíguos na seleção de alvo. A fachada pública `UnifiedBattle` normaliza PP ausente para zero, então o painel apresenta `0/0` e bloqueia essa escolha conforme o contrato que realmente chega ao mod.

O runtime harness verifica que o mod chama os pontos de entrada de fonte, moldura, paleta e cursor do motor para os onze títulos, preserva os layouts distintos de FRLG, Ruby/Sapphire e Emerald, não desenha cartões vetoriais ou texto com a fonte padrão do LÖVE, e mantém as intenções de menu, golpe, alvo, Mimic e Safari. Os testes também cobrem PP normalizada, slots não sequenciais, alvos esparsos, papéis dos battlers, mudança do slot ativo, prompts/revisões antigos, toques atrasados, avisos de rejeição e restauração dos controles nativos.
