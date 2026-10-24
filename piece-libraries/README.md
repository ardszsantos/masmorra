# Peças — formato v2

No Room Builder, desenhe chão e paredes. As faixas azuis na grade mostram as
aberturas automáticas. Não existem marcadores de entrada, saída, inimigos,
categorias ou botões de direção. O interior desenhado é preservado.

**Salvar projeto** guarda trabalho incompleto em `.piece_project.json`.
**Exportar para o jogo** confere cada peça e uma dupla jogável para cada uma,
usando exatamente o mesmo código de geometria e montagem do jogo.
Copie o `.piece_library.json` exportado para esta pasta e reinicie o jogo.
Projetos não são carregados pelo jogo. Arquivos v1 não são compatíveis.

O formato contém `format: "masmorra.piece_library"`, `version: 2`,
`rules_version: 1` e `pieces`. Cada peça tem somente `id`, `name`, `width`,
`height` e `rows` (0 vazio, 1 chão, 2 parede).

## Montagem

- Margens vazias não ocupam espaço. Chão exposto recebe um contorno de parede.
- Uma abertura automática ocupa 13 tiles na borda e precisa de chão livre
  em uma faixa de 13 × 3 imediatamente para dentro dela.
- O algoritmo escolhe uma abertura por lado, preferindo a mais central.
- Cima conecta a baixo; esquerda conecta a direita. Não há rotação ou espelho.
- As peças podem repetir. Cada sala contém 2–4 peças e ocupa até 99 × 81 tiles.
- O encaixe abre somente as bordas utilizadas. Paredes internas são preservadas.
- Todas as áreas caminháveis precisam estar ligadas por passagens de 3 tiles.
- Entrada, saída e posições de inimigos são escolhidas após a montagem.
- Uma dupla aprovada ao carregar garante um fallback; uma tentativa de expansão
  malsucedida conserva a montagem jogável. O jogo não depende de sorte para
  atingir o mínimo de duas peças.

As regras geométricas são versionadas em `scripts/gameplay/piece_rules.gd`,
copiado da fonte canônica `RoomBuilder/app/piece_rules.gd` pelo script
`RoomBuilder/tools/publish_to_game.ps1`. Não edite a cópia isoladamente.
Limites e distâncias geométricas não têm overrides independentes no Inspector.
Quantidade de inimigos, progressão, recompensas e arte continuam no jogo.

Bibliotecas inválidas recebem um erro com arquivo e peça; outras bibliotecas
válidas continuam carregando. Não use JSON editado manualmente para contornar
as verificações do exportador.
