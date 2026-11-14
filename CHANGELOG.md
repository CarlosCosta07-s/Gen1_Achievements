# Changelog

## 0.3.0 — Primeira rodada de conquistas

- Inserida a opção Achievements / Conquistas / Logros no menu START antes de OPTIONS.
- Registrada uma tela própria compatível com a Portable Mod API 3 nas três gerações.
- Adicionados filtros All / Unlocked / Locked e visualização de detalhes.
- Implementados objetivos instantâneos e contadores incrementais a partir de eventos.
- Adicionada persistência local por título, independente dos saves, por meio de `mod.cache`.
- Adicionada notificação visual após desbloqueios persistidos.
- Mantida a seleção de idioma English / Português (Brasil) / Español.
- O catálogo segue vazio até a pesquisa e validação das primeiras conquistas; nenhum título genérico foi publicado.

- Adicionadas 11 conquistas iniciais, uma por jogo, com traduções em inglês, português brasileiro e espanhol.
- Adicionado suporte a campos de evento aninhados, como `mon.species`.
- Corrigida a composição do hook do menu START para preservar entradas inseridas por outros mods.
- O validador agora verifica o índice JSON, o catálogo TSV e pelo menos uma conquista por jogo.
