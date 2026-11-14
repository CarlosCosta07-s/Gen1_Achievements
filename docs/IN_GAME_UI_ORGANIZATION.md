# Organização das interfaces dentro do jogo

## Escopo

A reorganização é entregue pelo mod Gen1 Achievements e aplicada aos onze jogos listados em manifest.json. Nenhum arquivo do repositório Gen1Recomp é alterado.

O objetivo é facilitar a localização das configurações, aproximando a organização de um jogo para PC ou Android, mas sem criar um tema visual novo. Permanecem intactos fontes, cores, bordas, ícones, molduras, proporções, animações e controles nativos.

## Configurações do Gen1 Achievements

As opções próprias do mod ficam exclusivamente no gerenciador de MODS dentro do jogo. mod.options:define registra achievement_language, que oferece English, Português (Brasil) e Español.

- Gen 1: o gerenciador de mods abre pelo atalho F10.
- Gen 2 e Gen 3: o gerenciador abre em START → MODS.

A página global Extras do launcher foi descartada. Não haverá cópia dessas configurações fora do gerenciador interno de mods.

## Organização do menu OPTIONS

O mod usa o hook público ui.options.rows, disponível em Gen 1, Gen 2 e Gen 3. O hook recebe os descritores nativos, chama a cadeia seguinte uma vez e devolve a mesma lista de opções em ordem revisada.

A sequência interna adotada acompanha as categorias existentes no menu do jogo:

| Categoria nativa | Ordem interna |
| --- | --- |
| Audio | Audio mode, Music volume, SFX volume, Pikachu volume (quando houver), Music filter |
| Video | UI layout, Orientation, Video mode, Faithful resolution, Screen position, VSync, Max FPS, Logic clock |
| Graphics | Colors, Shader FX, Shader FX 2, UI letterbox |
| Battle | Battle style, Animations, Battle layout, Battle fit, Battle HUD, Battle background |
| Speed | Text speed, Overworld speed, Battle speed, Menu speed |
| Extras | Tilt, Zoom, Void fill |

A ordem externa das categorias continua sendo responsabilidade da interface nativa de cada jogo. O mod reorganiza somente os itens dentro das categorias reconhecidas pelo jogo.

## Submenus da equipe

O hook `ui.party.submenu` agrupa ações comuns como STATS/SUMMARY, SWITCH, MOVE, ITEM/MAIL e CANCEL. Movimentos de campo (CUT, FLY, SURF etc.), descritores desconhecidos e linhas adicionadas por outros mods mantêm suas posições e callbacks. O submenu específico de batalha prioriza SWITCH, STATS e CANCEL.

Referências do contrato público: [Reference Hooks](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Hooks) documenta ui.options.rows para as três gerações; [Reference Mod Object](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Mod-Object) documenta que as linhas registradas com mod.options:define aparecem no gerenciador de mods.

## Compatibilidade com outros mods

A rotina trabalha apenas com IDs nativos conhecidos. As opções sem ID reconhecido e as linhas adicionadas por outros mods conservam suas posições. Os objetos de cada linha não são reescritos: callbacks, valores, rótulos, estado e outros campos são preservados.

Se uma versão não fornecer o hook, o mod não tenta editar menus por acesso interno. Se a cadeia de hooks devolver um valor diferente de uma tabela, o valor é passado adiante sem transformação.

## Testes

tests/runtime_harness.lua simula o hook de opções para os onze títulos e confirma:
- sequência interna de áudio, vídeo, gráficos, batalha, velocidade e extras;
- manutenção do número de linhas;
- preservação das linhas de outros mods e dos campos dos descritores;
- registro contínuo de achievement_language no gerenciador de MODS;
- passagem transparente de respostas inválidas da cadeia seguinte.

Os testes simulados verificam a lógica do mod, mas não substituem a confirmação visual dentro de cada versão executável.
