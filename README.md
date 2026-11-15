# Gen1 Achievements

Mod de conquistas para Pokémon Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire e Emerald no Gen1Recomp.

> **Estado:** catálogo com 216 conquistas (19–20 por jogo), objetivos de assinatura próprios para os onze títulos, três idiomas e proteção contra desbloqueios retroativos obtidos por edição do save.

## Experiência dentro do jogo

- Nova opção compacta **CONQ.** no menu START, posicionada antes de OPTIONS; o título completo aparece dentro da tela.
- Menu de batalha redesenhado pelo mod com referência estrutural em Pokémon Black/White e variação visual por título, incluindo os seletores especiais Mimic e Safari Zone de Gen 1.
- Tela de conquistas com navegação pelo D-pad e botões A/B/START; em Gen 3, usa a área GBA completa (240×160). O título e o nome do jogo mantêm a fonte Plain Pixel, enquanto resumo, filtros, lista, descrições e controles usam uma fonte sem serifa maior e mais simples. Descrições ocupam até três linhas, o progresso de conquistas incrementais fica junto ao status e o rodapé permanece dentro da moldura.
- Filtros All / Unlocked / Locked, com instrução de navegação no rodapé.
- Detalhes e descrições das conquistas.
- Contadores de progresso para conquistas incrementais.
- Notificação na tela quando uma conquista é desbloqueada.
- Conquistas secretas podem esconder título e descrição até o desbloqueio.

A interface usa os hooks oficiais da Portable Mod API 3. O item de conquistas, a tela e a reorganização das opções são aplicados pelo próprio mod; não é necessário modificar o código-base do Gen1Recomp.

As opções do Gen1 Achievements ficam no **gerenciador de MODS dentro do jogo**. No Gen 1, o gerenciador é aberto pelo atalho F10; no Gen 2 e Gen 3, pelo menu START → MODS. A configuração de idioma continua nessa área e não será duplicada nas opções gerais do jogo.

## Configurações dos jogos

O mod reorganiza as opções nativas e as ações comuns dos submenus da equipe, sem redesenhar esses menus. Fontes, cores, molduras, ícones, animações e controles nativos permanecem intactos; movimentos de campo e entradas de outros mods mantêm suas posições. A única interface refeita integralmente é o menu de batalha, que tem uma composição própria e onze variações de tema.

## Menu de batalha

A nova interface usa uma bandeja escura e cartões claros, com hierarquia inspirada em Pokémon Black/White. Cada jogo usa um acento cromático e acabamento próprios: Red, Blue, Yellow, Gold, Silver, Crystal, FireRed, LeafGreen, Ruby, Sapphire e Emerald. A seleção mostra nome, tipo e PP dos golpes e oferece alvos nas batalhas duplas quando a API fornece esses dados. Os cartões de alvo exibem barras compactas de HP, indicadores coloridos para condições de estado reconhecidas e um destaque claro para o cartão atualmente percorrido pelo cursor. O mod não classifica alvos como indisponíveis sem um dado público do motor que sustente essa decisão. Em batalhas duplas, o painel identifica o Pokémon que está comandando, exibe seu HP atual em uma barra compacta quando os dados públicos estão disponíveis e diferencia o aliado dos adversários; a troca de equipe continua nativa.

O mod não inclui sprites, fontes ou recursos extraídos de Black/White. Ele envia escolhas semânticas para o motor por meio da API pública de batalha. A navegação funciona com teclado, gamepad, controles virtuais Android/iOS e toque direto; toques são descartados quando o painel visível pertence a uma revisão/fase anterior da batalha. A mochila, a equipe, a execução dos golpes e as regras do combate continuam nativas. Rejeições específicas de alvo retornadas pelo motor recebem avisos localizados no painel, sem tentar antecipar as regras de cada golpe. Seleção forçada de equipe e mensagens também permanecem sob controle do jogo. Consulte [docs/BATTLE_UI.md](docs/BATTLE_UI.md).

## Ajuste de tela integrado

O próprio **Gen1 Achievements** ajusta a área de jogo por meio do hook público `render.viewport`; não é necessário instalar ou ativar um segundo mod:

- Gen 1 e Gen 2: proporção nativa 10:9.
- Gen 3: proporção nativa 3:2.
- Calcula o maior retângulo centralizado disponível na janela, respeitando o DPI e as áreas reservadas por outros mods.
- Mantém a mesma escala nos dois eixos; sprites e cenários não são esticados.
- Usa barras laterais ou superior/inferior quando a proporção do aparelho não coincide com a do jogo.
- Os controles virtuais continuam desenhados sobre a janela inteira e não são reduzidos com a imagem do jogo.

O hook altera somente o retângulo de apresentação. No PC, o modo Fullscreen/Borderless do sistema continua sendo controlado pelas opções nativas de vídeo do Gen1Recomp; o mod aproveita a maior área que o motor disponibiliza. Não há um addon de viewport separado no pacote atual: o ajuste é parte do Gen1 Achievements.

## Jogos e perfis

Os onze jogos têm catálogos e arquivos de progresso independentes:
- Red, Blue e Yellow;
- Gold, Silver e Crystal;
- FireRed e LeafGreen;
- Ruby, Sapphire e Emerald.

O progresso é armazenado por título, compartilhado entre os saves daquele jogo na mesma instalação. A persistência usa `mod.cache`, fora do arquivo de save. O mod só desbloqueia conquistas quando recebe eventos reais durante uma sessão pronta; flags que já estavam gravadas no save ao carregá-lo não são varridas para conceder conquistas retroativas. Ainda não há sincronização de conta ou nuvem.

## Idiomas

O idioma escolhido no gerenciador de MODS dentro do jogo controla os textos da tela, nomes e descrições:
- `en` — English
- `pt-BR` — Português (Brasil), padrão
- `es` — Español

## Catálogo

`data/achievements.tsv` é a fonte de dados executada pelo mod. Cada linha declara jogo, id, evento, condição (inclusive caminhos aninhados como `mon.species`), tipo de progresso, se é secreta, título e descrição nos três idiomas.

Cada jogo contém entre 19 e 20 conquistas de Pokédex, evolução, batalhas, insígnias, história, exploração e recursos próprios da geração. Além dos marcos gerais, cada título possui uma conquista de assinatura com uma condição própria: Electabuzz (Red), Magmar (Blue), crescimento do Pikachu parceiro (Yellow), Mankey (Gold), Delibird (Silver), Battle Tower (Crystal), Wooper (FireRed), Slowpoke (LeafGreen), Zangoose (Ruby), Seviper (Sapphire) e acesso à Battle Tower da Battle Frontier (Emerald). Johto inclui os dois circuitos de ginásios, além de Unown, Bug-Catching Contest, Apricorns, ovos e Pokérus; Hoenn inclui os Regis, os Pokémon errantes, fitas e ovos; FireRed/LeafGreen incluem o conteúdo normal das Ilhas Sevii. Nenhuma conquista depende de Mystery Gift, tickets de distribuição, ilhas temporárias, trocas online ou link play.

## Arquivos principais

- `manifest.json` — Portable Mod API 3 e os onze jogos.
- `main.lua` — menu START, organização de submenus, menu de batalha, viewport integrado, tela, persistência, eventos e notificações.
- `data/achievements.tsv` — catálogo localizado.
- `data/games.json` — títulos e ordem dos jogos.
- `data/ui_locales.tsv` — textos de interface carregados pelo mod.
- `data/ui_locales.json` — espelho legível das traduções para ferramentas de validação.
- `docs/` — arquitetura, armazenamento, integridade, contrato dos eventos e especificação do menu de batalha.
- `tests/validate_catalog.py` — validação estrutural e de traduções.
- `tests/validate_engine_contract.py` — verificação de eventos, campos e tipos contra a revisão fixada do motor.
- `tests/runtime_harness.lua` — execução controlada do `main.lua`, incluindo o menu START, viewport integrado e navegação da tela de conquistas, com uma API de teste.

## Validação e testes

Execute localmente a validação estrutural e a verificação do contrato de eventos, além da sintaxe LuaJIT e do harness:

```bash
python3 tests/validate_catalog.py
python3 tests/validate_engine_contract.py
luajit -b main.lua /tmp/gen1-achievements.luac
luajit tests/runtime_harness.lua
```

O validador do catálogo verifica as 15 colunas do TSV, IDs únicos, três idiomas, operadores, limites de 19–20 conquistas por jogo e a existência de onze objetivos de assinatura com condições distintas. O contrato de eventos confere disponibilidade por geração, caminho de campo, tipo do valor comparado e as diferenças de payload entre Gen 1, Gen 2 e Gen 3. A referência do motor fica fixada em `tests/engine_event_contract.json`, para que a validação não mude silenciosamente quando o upstream evoluir.

O harness carrega o `main.lua` real com uma implementação controlada da Portable Mod API 3 e exercita as 216 linhas do catálogo. Também executa os hooks do menu START, das opções gerais, do submenu da equipe e de `render.viewport`, verificando a preservação das proporções 10:9 e 3:2 em desktop, Android retrato/paisagem, DPI alto e viewports compostos. A camada visual percorre a tela de conquistas nos onze títulos e três idiomas, incluindo os cinco jogos de Gen 3 com o formato real de sessão (`generation = 3`, `save = nil`, `session.version`), verificando os tamanhos das fontes, a filtragem de texto, a largura máxima, o limite vertical do rodapé e a disposição de até três linhas nas descrições. Para o menu de batalha, snapshots sintéticos verificam os quatro comandos, golpes com tipo e PP, Mimic e Safari em Gen 1, alvos de duplas e IDs esparsos, atualização da lista de alvos, descarte de comandos e toques após mudança de fase/revisão, avisos de alvos rejeitados em três idiomas, retorno com B, passagem nativa por seleção forçada de equipe/mensagens, toque, cores e variações por título. Os testes de dados continuam cobrindo bloqueios de sessão, isolamento entre jogos, migração do perfil legado, rejeição de perfis malformados, preservação de progresso válido, criação de save novo e falhas de gravação.

Esses testes automatizados não substituem testes dentro das versões executáveis dos onze jogos. Até aqui, não foi feita uma partida real de validação com ROMs.

## Referências técnicas

- [Cookbook: UI and Infrastructure](https://github.com/bryanthaboi/gen1recomp/wiki/Cookbook-UI-And-Infrastructure)
- [Reference: Mod Object](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Mod-Object)
- [Reference: Events](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Events)
- [Reference: Hooks](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Hooks)
- [Concepts: Save Model](https://github.com/bryanthaboi/gen1recomp/wiki/Concepts-Save-Model)
- [Event contract revision](https://github.com/bryanthaboi/gen1recomp/commit/825f1670aeecb4a72345fb473d287fd8ea502ad2)

Nenhuma ROM, save, firmware, imagem extraída ou outro dado proprietário é incluído no repositório.
