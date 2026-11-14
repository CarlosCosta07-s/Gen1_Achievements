# Changelog

## 0.4.0 — Catálogo ampliado e proteção de sessão

- Expandido o catálogo para 17–20 conquistas por jogo, mantendo os onze títulos independentes.
- Adicionados objetivos de Pokédex, evolução, batalhas, insígnias, Campeão e exploração.
- Incluídos os dois circuitos de ginásios em Gold, Silver e Crystal.
- Incluídos Bug-Catching Contest, Unown, Apricorns, ovos, amizade e Pokérus nos jogos que possuem essas mecânicas.
- Incluídos os Regis, Pokémon errantes, fitas, puzzles de braille, Sky Pillar e Seafloor Cavern em Ruby, Sapphire e Emerald.
- Incluído o pós-jogo normal das Ilhas Sevii, sem exigir tickets ou distribuição limitada.
- Adicionados os operadores `one_of`, `one_of_true` e `ends_with` para espécies, transições de flags e identificadores de mapas.
- O processamento pausa durante `save.loading` e só recomeça após `save.loaded` ou `save.created`.
- Perfis locais agora validam IDs e contadores contra o catálogo e regravam perfis legados no formato 2 após a próxima atualização persistida.
- Documentado o modelo de integridade e seus limites: não é uma assinatura criptográfica contra quem modifica o próprio mod/cache.
- Adicionado validador de eventos por geração e limites de 17–20 conquistas por título.
- Adicionado harness de runtime que percorre as 205 definições do catálogo através do `main.lua` e verifica sessão, correspondência, deduplicação, isolamento de perfis, migração legada e falhas de gravação.
- GitHub Actions passou a executar o validador, a verificação de sintaxe LuaJIT e o harness de runtime em cada push para `main`.

## 0.3.0 — Primeira rodada de conquistas

- Inserida a opção Achievements / Conquistas / Logros no menu START antes de OPTIONS.
- Registrada uma tela própria compatível com a Portable Mod API 3 nas três gerações.
- Adicionados filtros All / Unlocked / Locked e visualização de detalhes.
- Implementados objetivos instantâneos e contadores incrementais a partir de eventos.
- Adicionada persistência local por título, independente dos saves, por meio de `mod.cache`.
- Adicionada notificação visual após desbloqueios persistidos.
- Mantida a seleção de idioma English / Português (Brasil) / Español.
- Adicionadas 11 conquistas iniciais, uma por jogo, com traduções nos três idiomas.
- Adicionado suporte a campos de evento aninhados, como `mon.species`.
- Corrigida a composição do hook do menu START para preservar entradas inseridas por outros mods.
- Adicionado CI para validar o catálogo e a sintaxe LuaJIT.

## 0.1.0–0.2.0 — Fundação e console

- Criado manifesto Portable Mod API 3 com os onze jogos.
- Implementada a seleção de idioma no launcher.
- Criada a tela de conquistas, filtros, detalhes, progresso e notificações.
- Definido o armazenamento local por título.

- Corrigidos os filtros de entrada em mapa para comparar sufixos estáveis, evitando depender do prefixo de Gen 3.
- Removida uma conquista duplicada de Marowak em cada título de Kanto e adicionada a captura de Snorlax como objetivo separado.
