# Modelo de integridade e proteção contra manipulação de saves

## Objetivo

Impedir que um arquivo de save editado retroativamente conceda conquistas apenas por já conter uma insígnia, flag de história, espécie ou resultado.

## Como o mod faz isso

1. **Progresso fora do save:** cada título grava seus desbloqueios em `mod.cache`, num caminho independente (`profiles/red.dat`, `profiles/gold.dat`, etc.). Alterar o arquivo de save não altera o perfil de conquistas.
2. **Somente eventos ao vivo:** o mod não varre as flags, a Pokédex ou o time ao carregar uma partida para conceder conquistas históricas. Ele escuta eventos do motor como `pokemon.caught`, `pokemon.evolved` e `flag.changed`.
3. **Sessão bloqueada durante carregamento:** `save.loading` desativa o processamento. `save.loaded` ou `save.created` reativa o processamento para a partida pronta.
4. **Flags apenas quando mudam para verdadeiro:** conquistas de insígnias e história exigem `flag.changed` com `value=true`, não apenas uma flag já marcada no arquivo. O campo `name` é textual em Gen 1, numérico em Gen 2 e pode ser textual ou um ID resolvido em Gen 3; as condições foram preparadas para esses tipos.
5. **Validação do perfil externo:** o formato 2 verifica se cada ID existe no catálogo do jogo correto, rejeita IDs duplicados, linhas malformadas e progresso incompatível com o objetivo. O formato 1 é aceito como legado e regravado no formato 2 quando ocorre a próxima atualização persistida.

## O que isso impede

- Editar o save para colocar uma insígnia não cria o evento de vitória que a concederia.
- Alterar a Pokédex para marcar espécies como capturadas não reproduz `pokemon.caught`.
- Um save antigo já concluído não recebe conquistas retroativas automaticamente.
- Um save carregado não transforma flags históricas em novos desbloqueios.

## Limites honestos

Isto é uma proteção local contra desbloqueios retroativos por edição do save, não um serviço antitrapaça online. Alguém que modifique deliberadamente o próprio mod, o cache privado ou o executável ainda pode falsificar dados locais. O projeto não usa servidor de autenticação, assinatura remota ou sincronização de conta. Não apresentamos um checksum embutido no código Lua como se fosse uma assinatura criptográfica: a chave poderia ser extraída do próprio pacote.

A experiência é single-player e offline. A intenção é preservar o mérito das conquistas sem recolher dados nem exigir conexão.
