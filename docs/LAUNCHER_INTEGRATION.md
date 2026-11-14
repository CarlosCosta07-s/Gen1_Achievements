# Integração de conquistas

## Propriedade da implementação

Toda a lógica, os dados, a persistência, as telas e os testes desta funcionalidade pertencem ao repositório **Gen1 Achievements**. Não se deve implementar a página alterando arquivos do repositório Gen1Recomp.

## Menu START — implementado pelo mod

O mod usa o hook ui.start_menu.items para inserir **Achievements / Conquistas / Logros** logo depois de SAVE e antes de OPTION. A tela é registrada por mod.content.screens e aberta por mod.ui.push. O mesmo código funciona nas três gerações declaradas pelo manifesto.

A página atual oferece:
- resumo de conquistas desbloqueadas e porcentagem do jogo ativo;
- filtros Todas / Desbloqueadas / Bloqueadas;
- navegação D-pad, seleção por A e retorno por B/START;
- lista com rolagem e cinco linhas visíveis;
- detalhes e descrições localizadas;
- progresso de objetivos incrementais e conquistas secretas.

## Página global do launcher — pendente de extensão pública

**Status: não implementada.** A preferência de idioma está disponível em MODS → Gen1 Achievements. A página global **Extras → Conquistas**, fora da tela de jogo, é uma integração diferente.

A documentação pública consultada da Portable Mod API 3 expõe superfícies para conteúdo, mundo, hooks e eventos. A referência de hooks documenta ui.start_menu.items como ponto de extensão dos menus do jogo; mod.ui.push abre uma tela registrada no contexto do jogo. A referência também descreve core.quit_to_launcher como um hook de ciclo de vida, não como registro de páginas. Não há, no contrato público consultado, um hook ou registry para adicionar uma página ao painel global Extras.

Referências:
- [Portable Mods — API 3](https://github.com/bryanthaboi/gen1recomp/wiki/Guide-Portable-Mods)
- [Reference Hooks — menus do jogo e hooks do ciclo de vida](https://github.com/bryanthaboi/gen1recomp/wiki/Reference-Hooks)

Por isso, o mod não tenta chamar funções internas do launcher, injetar linhas em tabelas privadas, interceptar callbacks não documentados ou presumir que uma tela desenhada sobre o jogo possa ser aberta antes de um jogo estar carregado. Tais atalhos não seriam um contrato suportado e poderiam quebrar entre versões.

## Contrato de dados já existente para a futura página

A futura visualização deve continuar sendo somente leitura e usar os dados existentes no mod:
- catálogo localizado em data/achievements.tsv;
- IDs dos onze jogos definidos em manifest.json;
- perfis por título em profiles/<game>.dat, por meio de mod.cache;
- textos de interface em data/ui_locales.tsv.

Quando houver uma API pública de registro de páginas do launcher, a implementação deverá permanecer neste repositório e:
1. agregar os onze perfis sem misturar o progresso dos títulos;
2. mostrar total, desbloqueadas e porcentagem por jogo;
3. reutilizar os três idiomas já suportados;
4. não desbloquear conquistas nem modificar o perfil enquanto a página estiver sendo consultada;
5. continuar funcionando sem ROM, save ou conteúdo extraído incluído no pacote do mod.

Até que essa superfície exista, a tela do menu START é a interface oficial disponível e funcional. Esta pendência não altera o funcionamento das conquistas durante a partida.
