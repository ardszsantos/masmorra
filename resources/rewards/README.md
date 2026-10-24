# Recompensas da run

- `Main/RoomRewards`: configura o catálogo no Inspector. `Offer All Worlds` permite ofertas dos quatro mundos na mesma run.
- As ofertas são sorteadas sem repetição nas saídas existentes. Uma sala com uma saída oferece apenas uma recompensa. Se houver mais portas que recompensas distintas, as portas excedentes são retiradas daquela instância da sala.
- O jogador recebe a oferta ao atravessar uma saída liberada. A sala seguinte é construída antes de consumir a escolha. Só uma oferta pode ser recebida por sala.
- `laser.tres` aponta para `scenes/upgrades/laser.tscn`. Na cena, ajuste a cadência e seu ganho por nível. `plasma_projectile.tscn` expõe dano, velocidade, duração e máscara de colisão.
- O laser mira no inimigo vivo mais próximo cujo centro esteja na área visível da câmera. Cada projétil mantém a direção calculada no disparo, colide com paredes e inimigos, e expira sozinho. Nível 1: intervalo de 1,1 s; cada nível adiciona 18% à taxa base, até o intervalo mínimo de 0,18 s.
- `Player/Upgrades` mantém os efeitos e seus níveis entre salas. `grant_upgrade()` equipa ou sobe de nível; `remove_upgrade()` remove um efeito. Nenhuma regra do laser está em `player.gd`.
- Vida e stamina participam do catálogo ativo junto com os upgrades. Vida concede +20 de vida máxima e recupera 20 de vida; stamina concede +20 de stamina máxima. Esses boosts valem durante a run e não ocupam slots de passivas na mochila.
- Espaço: jetpack deixa fogo no trajeto do dash. Mundo normal: shuriken carrega automaticamente, independentemente do movimento, inclusive com a sala limpa. Ao completar a carga e encontrar um inimigo próximo e visível em combate, dispara uma rajada simultânea em asterisco; sem alvo, guarda a carga.
- Medieval: olho de gorgona congela periodicamente o inimigo próximo e visível mais próximo; anel incendiário cria uma barreira temporária de fogo ao redor do jogador, acompanhando seu movimento.
- Polygons: triangelo acompanha o jogador e se arremessa contra inimigos próximos.
- As cenas em `scenes/upgrades` expõem os parâmetros das passivas no Inspector. Níveis melhoram os parâmetros próprios de cada upgrade. Efeitos temporários são removidos ao trocar de sala, morrer ou desequipar.
- Após eliminar os inimigos, `Main/HUD/RewardGuides` mostra bolhas com ícone, mundo e nível. Fora da tela, apontam para a porta a partir da borda; perto dela, ficam sobre a porta.
