# Integração no launcher: Extras → Conquistas

## O que já existe

A API de mods do Gen1Recomp oferece `mod.options:define`. Opções declaradas pelo mod aparecem automaticamente no gerenciador de mods do launcher e são guardadas nas opções do aplicativo, sobrevivendo a New Game.

Este repositório define a opção `achievement_language` com três valores:
- `en`
- `pt-BR`
- `es`

A preferência padrão é `pt-BR`. O mod também emite `mod.gen1_achievements.language_changed` quando essa opção é alterada.

## O que ainda exige integração no aplicativo

A documentação pública de modding consultada não apresenta uma API para um mod acrescentar uma nova aba de primeiro nível ao launcher. Por isso, **Extras → Conquistas não pode ser declarado como concluído apenas com o pacote deste repositório**.

A alteração complementar deverá ser feita no repositório do Gen1Recomp:

1. Adicionar **Extras** à navegação principal do launcher.
2. Adicionar **Conquistas** como página de Extras.
3. Listar os onze jogos como seções/cartões independentes.
4. Para cada jogo, mostrar conquistas desbloqueadas, total, percentual e histórico.
5. Colocar o seletor English / Português (Brasil) / Español dentro da página de Conquistas.
6. Fazer o seletor ler e gravar a mesma opção `achievement_language`; não criar uma segunda preferência divergente.
7. Atualizar imediatamente os nomes e as descrições após a troca de idioma.

## Contrato visual esperado

- A página não deve misturar os totais de versões diferentes.
- Jogo sem catálogo deve mostrar um estado vazio localizado, não uma porcentagem enganosa.
- Conquistas ocultas não devem revelar sua descrição antes do desbloqueio.
- O launcher deve continuar funcionando quando o mod estiver ausente ou desativado; nesse caso, mostrar uma mensagem explicativa ou ocultar a entrada de Conquistas.
- A leitura de progresso deve usar uma interface pública e versionada. Não acoplar o launcher a caminhos privados de arquivos ou a uma estrutura interna não documentada.
