# Arquitetura do Gen1 Achievements

## Interface dentro do jogo

A implementação usa as superfícies oficiais da Portable Mod API 3:
- Hook `ui.start_menu.items` para inserir a opção logo depois de `SAVE`, mantendo-a antes de `OPTION`.
- `mod.content.screens:register` para registrar a tela própria.
- `mod.ui.push` para abrir a tela a partir da opção do menu.
- Tela com `update(dt)` e `draw()`, usando `game.input:wasPressed` para D-pad, A, B e START.

O mesmo contrato é usado nas três gerações. A opção do menu ajusta sua largura automaticamente com base no maior rótulo, permitindo nomes localizados mais longos. O hook `ui.start_menu.items` é o ponto de extensão do menu do jogo.

## Comportamento de console

A tela implementa:
- resumo total/desbloqueadas;
- filtros geral, desbloqueadas e bloqueadas;
- navegação por lista e tela de detalhes;
- conquistas secretas;
- progresso numérico em objetivos incrementais;
- instrução localizada para alternar filtros no rodapé da lista;
- notificação curta na tela após o desbloqueio.

O desbloqueio é disparado por eventos oficiais. A linha de catálogo define o evento e sua condição. O sistema só se inscreve em eventos que a versão em execução declara suportar por `mod:supports("events", name)`. O catálogo usa eventos reais de captura, evolução, batalha, mudança de flag, entrada em mapa, reprodução, amizade, Pokérus e mecânicas exclusivas de Johto.

## Menu de batalha redesenhado

O menu de batalha é a única interface refeita integralmente pelo mod. O desenho original usa uma bandeja escura, cartões claros, destaque cromático por título e cartões de golpe com nome, tipo e PP. A estrutura de composição toma Pokémon Black/White como referência, sem reutilizar seus assets.

O snapshot é lido por `mod.battle:snapshot()`. As escolhas são enviadas por `mod.battle:submit()` com `revision` e ID crescente de intenção:
- `menu` para Fight, Item/Pack/Bag, Pokémon e Run;
- `move` para selecionar o slot nativo do golpe. Gen 1 expõe `curMoves`, Gen 2 expõe `moves`, e Gen 3 compacta a lista visível mas preserva o número real em `slot`;
- `target` apenas na API da terceira geração, que expõe IDs de battler de 0 a 3. Esses IDs podem ser esparsos; a seleção usa o ID nativo, não o índice da grade. Se a lista muda durante o prompt, o cursor preserva o ID selecionado quando possível. Antes de submeter, o mod relê o snapshot e confirma que a intenção ainda corresponde à fase ativa. Em batalhas duplas, `active` identifica o slot do jogador que está recebendo comandos (0 ou 2), e `battlers[].side` distingue aliados de adversários; o painel mostra esse contexto sem substituir a fase nativa `party`;
- `mimic` para escolher, no Gen 1, um dos movimentos que o motor autorizou copiar;
- `safari` para executar Ball, Bait, Rock ou Run no menu próprio da Safari Zone;
- `back` para retornar da seleção normal de golpe/alvo.

A fachada pública `UnifiedBattle` normaliza PP ausente para zero antes de entregar o snapshot ao mod; por isso, o cartão apresenta `PP 0/0` e bloqueia a seleção. O campo `disabled` também é respeitado quando fornecido.

Os hooks `input.key`, `input.gamepad` e `input.pointer` capturam teclado, controle físico e toque direto somente quando uma fase substituível está ativa. `input.step` encaminha as entradas do overlay virtual Android/iOS antes do processamento nativo. `overlayPressed` registra também os toques curtos entre passos; A/B/D-pad são mascarados apenas quando pertencem ao overlay e apenas no passo que consome a borda, preservando teclado, gamepad e outras fontes. O ponteiro é convertido de coordenadas da janela para o espaço lógico do painel, considerando origem e escala do viewport. O hook `render.hud` desenha o painel sobre a parte inferior do frame. `battle.bottom_ui_visible` esconde a camada nativa nas versões em que a superfície está disponível; se não estiver, o painel vetorial cobre a região inferior. A HUD superior continua nativa.

O motor permanece responsável por processar turnos, golpes, PP, alvos, itens, captura, trocas, animações e mensagens. Cada entrada permanece vinculada ao prompt e à revisão capturados pelo hook; a submissão relê o snapshot e descarta a ação se qualquer um dos dois mudou, mesmo quando o prompt permanece igual. O mod não tenta reconstruir categorias de alvo que a API pública não expõe. As escolhas de Bag e Pokémon voltam aos fluxos originais do jogo. A API pública não expõe uma intenção para alternar diretamente o battler ativo de uma batalha dupla; por isso, o painel apenas identifica o Pokémon que recebeu o comando e mantém a troca de equipe sob controle do jogo. A seleção forçada de equipe, o avanço de mensagens, as fases bloqueadas, batalhas Link e tutoriais não são capturados pelo painel; ao sair de uma fase substituída, a ponte de toque é restaurada. Nenhum HP, PP, save ou estado de batalha é escrito diretamente pelo mod.

As onze variações cromáticas e suas diferenças de acabamento estão em `BATTLE_THEMES` no `main.lua`; a especificação funcional e visual fica em `docs/BATTLE_UI.md`.

## Fonte de dados

`data/achievements.tsv` é a fonte de dados executada pelo mod. Colunas (15, separadas por TAB):

1. game
2. id
3. event
4. match_field
5. operator (`any`, `equals`, `at_least`, `truthy`, `one_of`, `one_of_true`, `ends_with`)
6. match_value
7. mode (`instant` ou `counter`)
8. target
9. secret (`true` / `false`)
10. title_en
11. description_en
12. title_pt-BR
13. description_pt-BR
14. title_es
15. description_es

Para `operator=any`, use `*` em `match_field`. Os campos também aceitam caminhos aninhados, como `mon.species`. `one_of` compara o campo com uma lista separada por `|`; `one_of_true` faz o mesmo e exige que `event.value == true`, para contar apenas a ativação real de uma flag; `ends_with` identifica mapas pelo sufixo estável de `mapId`, sem depender do prefixo específico de cada jogo. Em modo `counter`, cada ocorrência que satisfaz a condição incrementa o valor persistido até `target`.

Eventos usados incluem `pokemon.caught`, `pokemon.level_up`, `pokemon.evolved`, `pokemon.move_learned`, `battle.ended`, `map.entered`, `flag.changed`, `egg.hatched`, `happiness.changed`, `pokerus.infected` e eventos exclusivos de Johto. A disponibilidade é verificada por jogo e geração.

## Contrato de eventos do motor

`tests/engine_event_contract.json` registra os eventos, suas gerações e os tipos dos campos que o catálogo consome. A matriz foi conferida no Gen1Recomp `dev` em commit `825f1670aeecb4a72345fb473d287fd8ea502ad2`; o SHA está fixado para que o contrato não mude silenciosamente. `tests/validate_engine_contract.py` confere cada linha do TSV contra essa matriz, incluindo o campo booleano `value` que protege os contadores de flags e os IDs numéricos de Gen 2.

O snapshot é uma especificação testável do contrato documentado e dos produtores consultados; não é uma cópia do motor, nem substitui a execução de cada versão real. A atualização do upstream exige revisar a matriz e atualizar explicitamente a referência.

## Persistência e identidade

O perfil de conquistas é por instalação e por título, não por save. O formato 2 verifica cada ID e progresso contra o catálogo atual e descarta perfis malformados ou IDs de outro jogo; perfis legados do formato 1 são lidos e regravados no formato 2 na próxima atualização persistida. Isso detecta corrupção e edições casuais, mas não é assinatura criptográfica contra alguém que modifique o código ou o próprio cache.

A proteção contra manipulação do save é baseada no fluxo de eventos: `save.loading` desativa os desbloqueios, `save.loaded` e `save.created` reativam a sessão, e o mod nunca concede conquistas lendo flags antigas do save. Uma edição de `.sav` que apenas marque uma insígnia ou capture um Pokémon não cria, por si só, o evento de ação ao vivo necessário para desbloquear a conquista. No Gen 1, `flag.changed.name` é textual; no Gen 2, é numérico; no Gen 3, o motor fornece o nome resolvido e também o ID numérico. O comparador aceita essas formas sem depender de um scan do save.

Armazenamento:
- `mod.cache:read/write("profiles/red.dat")`, por exemplo;
- cada uma das onze versões usa um caminho separado;
- começar um New Game não reinicia conquistas do mesmo título;
- Red não compartilha progresso com Blue ou Yellow, e assim por diante.

Esse comportamento é mais próximo de conquistas vinculadas ao título em consoles modernos do que de objetivos presos a um save. O limite atual é que `mod.cache` é local à instalação. Não é uma conta online e não sincroniza dados entre dispositivos ou usuários do mesmo aplicativo.

## Testes automatizados

O repositório possui três camadas complementares de verificação:

1. `tests/validate_catalog.py` valida as 15 colunas do TSV, unicidade de IDs, idiomas, operadores, limites dos contadores e matriz de eventos autorizados por jogo.
2. `tests/validate_engine_contract.py` confere se cada evento possui um call site na geração correspondente e se os caminhos e tipos usados pelas condições existem no contrato fixado.
3. `tests/runtime_harness.lua` carrega o `main.lua` real e fornece uma implementação controlada das superfícies Portable Mod API 3 necessárias. O harness percorre cada linha dos onze catálogos e verifica correspondência de eventos, bloqueio antes de `save.loaded`/`save.created`, desbloqueio único, persistência no arquivo correto, separação entre títulos, migração do formato 1, rejeição de IDs estrangeiros, descarte integral de perfis malformados, preservação de perfis válidos e rollback quando a gravação falha. Também executa os hooks `ui.start_menu.items` e `ui.options.rows`: testa a posição da opção do mod, a ordenação interna de opções nativas nos onze títulos, a preservação de itens externos e o registro do idioma no gerenciador MODS. A tela é renderizada em todos os onze títulos e nos três idiomas; os testes verificam filtros, rolagem, detalhes, saída e sigilo das conquistas secretas.

Para executar:

```bash
python3 tests/validate_catalog.py
python3 tests/validate_engine_contract.py
luajit -b main.lua /tmp/gen1-achievements.luac
luajit tests/runtime_harness.lua
```

O harness exercita as 205 definições atuais com payloads sintéticos. As validações estáticas também usam uma matriz versionada do contrato do motor; nenhuma delas substitui testes dentro das versões executáveis dos onze jogos. A confirmação final exige testar as versões reais.

## Organização das opções do jogo e do mod

- O hook `ui.options.rows`, disponível nos onze jogos, reorganiza descritores de opções nativas dentro das categorias já fornecidas pelo menu do jogo.
- O mod ordena controles de áudio, vídeo, gráficos, batalha, velocidade e extras por uma sequência estável de IDs. Ele não desenha o menu de opções nem substitui a tipografia, cores, molduras, ícones, proporções ou controles nativos.
- Linhas desconhecidas ou de outros mods mantêm sua posição e seus descritores originais; o hook chama a cadeia seguinte uma única vez e só trabalha quando recebe uma tabela.
- A ordem externa das categorias continua pertencendo ao jogo. O mod ajusta somente a ordem das opções dentro delas, sem acessar funções internas do motor.
- `mod.options:define` mantém a opção `achievement_language` no gerenciador de MODS dentro do jogo. Ela não é duplicada nas opções gerais.

A navegação do gerenciador varia por geração: no Gen 1 ele é aberto pelo atalho F10; no Gen 2 e Gen 3, por START → MODS. A implementação do mod continua inteiramente neste repositório.

## Idioma

`mod.options` persiste `achievement_language` fora do save do jogo e oferece English, Português (Brasil) e Español. A tela carrega os textos de `data/ui_locales.tsv`, espelhados em JSON para ferramentas. O mesmo valor é usado para nomes e descrições; IDs, condições e progresso independem do idioma.
