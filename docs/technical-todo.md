# TODO técnico auditado

Revisão: 2026-11-06  
Fonte: auditoria estática do repositório `emanuelserpa/lume-shell`, branch
`main`, fornecida pelo usuário. O shell não foi executado numa sessão Wayland
durante a auditoria; riscos a reproduzir não são bugs demonstrados.

Este backlog complementa, e não substitui, o plano ativo em
[`design-plan.md`](design-plan.md). Preservar também
[`stability-contract.md`](stability-contract.md).

## Regras de execução

- Priorizar a sequência indicada abaixo e, para mudanças visuais, seguir as
  fases 1 → 2 → 3 → 4 de `design-plan.md`.
- Antes de cada mudança, registrar evidência/reprodução, arquivos a tocar e
  teste de regressão. Atualizar o documento de domínio pertinente no mesmo
  conjunto de trabalho.
- Distinguir defeito confirmado, risco a testar e melhoria de processo. Não
  redesenhar mídia, áudio, Bluetooth, notificações ou launcher por uniformidade.
- Não criar serviços sem consumidores reais. Não marcar tarefa concluída só
  porque o código mudou: registrar verificações e limitações.

## P0 — Próxima rodada

- [ ] **P0-01 — Fechar a Fase 1 do plano visual.** Arquivos: `bar/CalendarCard.qml`,
  `bar/SystemUpdatePopup.qml`, `bar/UpdateControl.qml`, `services/UpdateState.qml`,
  helper de atualizações e `docs/design-plan.md`. Testar virada de dia/mês/ano e
  retomada da suspensão com calendário aberto; atualizar a data apenas quando o
  usuário ainda navega no mês corrente. Reproduzir lista expandida junto com
  execução/erro; verificar clipping e acesso aos botões. Manter resultado/erro e
  acesso ao log após conclusão/reabertura, centralizar o caminho do log e
  apresentar erro legível se indisponível. Abrir log sem iniciar atualização.
  Aceite: relógio/falhas simulados, checklist visual, sem iniciar atualização
  real.
- [x] **P0-02 — Preservar arquivos locais em `scripts/validate.sh`.** A combinação
  `py_compile` + remoções abrangentes de `__pycache__` pode apagar caches
  preexistentes. Validar sem bytecode ou limpar apenas temporários próprios.
  Teste: criar sentinela `__pycache__` antes e confirmar que permanece intacta.
- [x] **P0-03 — Separar validação offline de sondagens vivas.** Criar `--offline`
  com unittest, verificações QML, contratos e helpers simulados. Tornar
  `quickshell ipc call spotlight toggle` opt-in; não tocar no Spotlight durante
  validação comum. Em CI, ferramentas QML obrigatórias ausentes falham; local
  pode emitir WARN explícito. Isolar sondagens de hardware/rede. `run_json_helper`
  não aceita JSON válido com subprocesso em erro. Aceite: offline sem Wayland,
  sem alterar Spotlight; CI falha sem dependências obrigatórias.
- [x] **P0-04 — Compatibilizar `scripts/visual-check.sh` com o pacote.** Detectar
  `lume-shell.service` primeiro; usar `quickshell.service` apenas como fallback
  explícito legado. Verificar unidade ativa, não só instalada. Condicionar
  verificações Hyprland ao compositor e avisar quando não aplicáveis. Aceite:
  sessão saudável do pacote passa; ausência de shell ativa falha.
- [ ] **P0-05 — CI de qualidade no GitHub (suspenso por enquanto).** A pedido do
  usuário, `quality.yml` foi removido e o workflow de pacote não depende mais de
  CI. Antes de reativar: resolver as cinco falhas observadas na primeira execução
  remota; a mesma suíte passou localmente (248 testes). O validador agora imprime
  os tracebacks completos em caso de falha. Reavaliar a proteção de release e
  exigir aprovação só quando o CI for retomado.

## P1 — Resiliência, integridade e distribuição

- [x] **P1-01 — Remoção do clipboard.** `clipboard-index.json` é escrito pelo
  snapshot e lido pelo comando legado `clipboard-cache`, então permanece como
  consumidor. A sincronização estava inalcançável depois do `finally`; foi movida
  para o fluxo de remoção e usa substituição atômica, mantendo SQLite como fonte
  de verdade se o cache falhar. Testes cobrem remoção do banco/cache, blob
  compartilhado e rejeição de assinatura desatualizada. `python3 -B -m unittest
  tests.test_clipboard`: 34 testes aprovados, incluindo remoção de thumbnail.
- [ ] **P1-02 — Histórico de notificações.** Risco a reproduzir: reinício fixo de
  1 s e fila `pendingStoreRequests` sem limite. Simular helper ausente/falhando e
  encerramentos repetidos; medir reinícios/log/memória. Só se reproduzido,
  adicionar backoff limitado, fila limitada e indisponibilidade observável; não
  descartar notificações sem política. O serviço real permaneceu ativo por 17 h
  com `notification_store.py` em execução; essa observação não reproduz falha nem
  reinícios. Requer simulação controlada antes de alterar retry/fila.
- [ ] **P1-03 — Ações externas e respostas fora de ordem.** Simular stdout vazio,
  stderr, rc != 0, processo pendente, consulta reiniciada e resposta antiga após
  uma nova. Corrigido o falso sucesso confirmado em `CommandAction` e
  `CommandJson`: ambos agora exigem código zero e `CommandJson.restart()` aguarda
  a saída do processo anterior, descartando sua resposta antes de iniciar a
  consulta atual. Um watchdog de 2 s reporta helper que não chega a iniciar, já
  que o `Process` disponível não expõe o erro de início como sinal QML. Cobertura
  pura para JSON vazio, stderr, código não zero, sucesso, start timeout e
  transição de restart: QML 121/121. Falta teste com `Process` real para processo
  que inicia e fica pendente, ordenação de sinais e feedback visual; item aberto.
- [ ] **P1-04 — Privacidade do clipboard.** Adicionar pausa/retomada de captura e
  preferência persistente quando apropriado. Avaliar apenas sinais sensíveis
  realmente expostos; não prometer detecção infalível de senhas. Preservar
  limites, WAL, deduplicação e lock; documentar limites de apagamento forense de
  SQLite/WAL/backups. Implementada pausa/retomada persistente pelo preview; o
  callback drena o pipe, mas não lê nem guarda novos conteúdos enquanto pausado.
  Testes cobrem preferência, comandos pause/resume e recusa de captura. Remoção
  limpa blob, thumbnail e índice/cache; falta validar a interação visual e
  ausência de novos itens por callback real. Limites forenses e ausência de
  detecção automática de senhas estão em `docs/clipboard.md`.
- [ ] **P1-05 — Contrato público de empacotamento.** Escolher licença antes de
  distribuir a terceiros e ajustar PKGBUILD. Em Arch limpo/VM testar build,
  instalação, serviço, IPC, atualização, remoção, opcionais e ausência de
  serviços duplicados. Consultas atuais ao GitHub retornaram zero tags, zero
  releases e nenhum arquivo de licença. Portanto 0.1.0 é apenas fallback para
  builds locais, e o workflow injeta a versão de uma tag; o `CHANGELOG.md` agora
  identifica 1.2.0 como marco funcional, e o título de `LAUNCHER.md` deixou de
  apresentar v0.20.27 como versão do produto. Ainda falta escolher e publicar a
  licença antes de distribuir; não vou inventá-la. O comando de build local
  `makepkg --nodeps --force --noconfirm` gerou `lume-shell-0.1.0-13`;
  `pacman -Qip` e o índice do archive confirmam metadados e arquivos, incluindo
  os novos componentes. Dependências
  foram explicitamente ignoradas, o pacote não foi instalado, e `namcap` não
  está disponível no host; isso não substitui o teste em Arch limpo/VM.
- [ ] **P1-06 — Temas e recuperação.** Risco a reproduzir com falhas isoladas de
  Kitty/GTK/labwc/Hyprland, configuração inválida e interrupção de escrita.
  Conferir aplicação real, estado reportado e repetição sem afetar adaptadores
  já sincronizados. Novos testes em diretórios temporários provam que uma
  substituição interrompida do arquivo do labwc preserva a configuração anterior
  e permite retry; settings.ini GTK inválido permanece fora de sync até reparo.
  `python3 -B -m unittest tests.test_theme`: 41 aprovados. A suíte também verifica
  isolamento entre adaptadores. Falta validar comportamento
  aplicado na sessão real (Hyprland/Kitty/GTK/labwc) sem mexer no estado vivo.

## P2 — Qualidade visual e desempenho medidos

- [ ] **P2-01 — Fase 2: legibilidade e teclado.** Depois da Fase 1, auditar
  atualizações/calendário/cabeçalhos e depois rede/Bluetooth/notificações/
  Spotlight. Testar Tab, Shift+Tab, Enter, Espaço, Escape, foco visível e rótulos
  completos. Medir contraste em Mocha e Chameleon claro/escuro/OLED; meta 4,5:1
  para texto normal. Cobertura automatizada já verifica contraste textual de
  temas integrados e variantes Chameleon em `tests.test_theme`; falta a matriz
  visual/teclado por superfície, tema e cenário. Preservar dimensões compactas.
- [ ] **P2-02 — Fase 3: movimento e componentes.** Avaliar preferência de movimento
  reduzido sem perder feedback; verificar saída e remoção de toasts. Unificar
  somente duplicações reais tocadas pelas correções anteriores; não reformar
  mídia/áudio estáveis. Aceite: fluxos com movimento normal/reduzido, prazos de
  toast corretos e consumidores reais para componentes compartilhados.
- [ ] **P2-03 — Fase 4: geometria e escala.** Testar um/dois monitores, 100% e
  escala fracionária, largura estreita e textos longos. Verificar colisões,
  conteúdo em popups, foco e ancoragem; preservar ordem da barra. Registrar
  evidências separadas por compositor e não declarar sessão não testada. A sessão
  atual oferece Hyprland, um monitor eDP-1 1920×1080 a escala 1; não cobre segundo
  monitor, escala fracionária nem os outros compositores.
- [ ] **P2-04 — Baseline de desempenho.** Medir idle CPU/RAM, subprocessos,
  abertura/primeiro caractere do Spotlight e troca de tema; comparar 1/2 monitores
  e popups fechados/abertos. A unidade real reporta 143 MiB atuais, pico de 1,3
  GiB e 2 h 8 min de CPU após 17 h; isso inclui uso não controlado e não permite
  atribuir pico ou CPU a idle. O log contém abertura do Spotlight em 23 ms. Só
  otimizar após gargalo medido. Registrar condições reproduzíveis, baseline e
  limite de regressão em `docs/performance.md` se útil.

## P3 — Manutenção quando houver dor demonstrada

- [ ] **P3-01 — Extrações pontuais.** Candidatos: Spotlight, ThemePreviewPane,
  NetworkPopup e `theme-manager.py`. Começar somente com dificuldade de teste,
  duplicação ou acoplamento demonstrados; extrair uma responsabilidade por vez.
  Tamanho do arquivo não é justificativa. Aceite: testes mais isolados ou
  duplicação removida, comportamento preservado e docs atualizados.

## Sequência sugerida

P0-01; depois P0-02 + P0-03 + P0-04; P0-05; P1-01 + P1-02; P1-03 a P1-06;
P2-01 a P2-04; P3-01 somente se houver dor real. Para UI, a ordem ativa segue
Fase 1 → Fase 2 → Fase 3 → Fase 4 em `docs/design-plan.md`.

## Definição de pronto

- [ ] Problema reproduzido ou risco justificável documentado; risco não rotulado
  como bug sem teste.
- [ ] Mudança pequena e reversível; comportamento estável preservado.
- [ ] Testes relevantes executados; limitações de ambiente registradas.
- [ ] Evidência de regressão, diagnóstico, medição ou checklist.
- [ ] Docs de domínio, `docs/current-state.md` e plano ativo atualizados quando
  afetados, junto da implementação.
