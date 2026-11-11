# Checklist de regressão visual

Use com o [guia de design](design-guidelines.md) e o
[contrato de estabilidade](stability-contract.md). Marcar apenas o que foi
verificado; registrar “não executado” com motivo para cenários indisponíveis.
Esta lista é um roteiro, não uma declaração de que a auditoria já foi feita.

## Registro da revisão

- Data, commit/alterações locais e superfícies afetadas:
- Compositor, monitor, resolução e escala:
- Tema, variante e wallpaper:
- Evidências (capturas, logs, verificações de interação):
- Limitações e pendências:

### P0-01 — calendário e atualizações (2026-11-08)

- Quickshell 0.3.2, Hyprland, monitor eDP-1 1920×1080, escala 1; serviço
  `lume-shell.service` ativo. Em 2026-11-08, `pacman -Q lume-shell` confirmou
  `0.1.0-13`, instalado da árvore atual para permitir a revisão interativa;
  `./scripts/visual-check.sh` passou com unidade ativa, layer-shell, barra de
  37 px e fontes exigidas. Isso confirma a instalação e a superfície, não a
  abertura do popup de atualizações.
- Harness isolado da árvore de trabalho: `/tmp/lume-p0-harness-panel.png`.
  Confere visualmente mês visitado, ação Hoje, progresso anual e feriados; não
  é captura do shell instalado nem valida navegação/interação.
- `./scripts/validate.sh --offline`: 17 OK, 0 WARN, 0 FAIL; testes QML 123/123
  (execução registrada para as alterações iniciais deste item).
  Os testes simulam as duas viradas e preservação do mês navegado.
- `./scripts/visual-check.sh` passou na sessão: serviço ativo, layer Quickshell
  presente, barra com 37 px e fontes exigidas instaladas.
- Harness integrado em `PanelWindow` com dados simulados, execução e erro:
  `/tmp/lume-p0-update-review-running.png` e
  `/tmp/lume-p0-update-review-error.png`. Em ambos, a lista expandida cabe no
  popup; o estado de erro e as ações ficam visíveis. O harness desativa `grabFocus`
  porque não recebe clique real; portanto não valida o caminho de foco/abertura
  usado pela barra nem o estado do shell instalado.
- `quickshell ipc --path /usr/share/lume-shell show` responde, mas só expõe
  spotlight, displayProjection, media e notifications; não há alvos para abrir
  calendário/atualizações. Na inspeção inicial, o pacote `0.1.0-12` diferia da
  árvore atual; ele foi substituído por `0.1.0-13` para o teste interativo. As
  capturas integradas anteriores continuam usando a árvore de trabalho.
- Em 2026-11-08, `python3 -B scripts/update-log.py status` retornou
  `has_status: false`; `python3 -B scripts/update-log.py open` retornou sucesso
  com o caminho `/home/emanuel/.cache/quickshell/update.log`, sem iniciar uma
  atualização. A janela temporária de `tail` foi encerrada após o teste.
- Continuam sem verificação: retomada real após suspensão; abertura do popup pela
  barra na instância instalada; estado visual persistido após fechar/reabrir; e
  ativação dos botões por mouse/teclado. O IPC disponível não controla esses
  estados, então P0-01 permanece aberto.

### P0-01 — nova conferência do estado instalado (2026-11-08)

- Em 2026-11-08, `pacman -Q lume-shell` retorna `0.1.0-14` e
  `lume-shell.service` está ativo usando `/usr/share/lume-shell`. O IPC
  instalado continua sem alvos de calendário ou atualizações. A abertura pela
  barra depende de clique real; a revisão visual do popup instalado segue
  pendente.
- Tentei abrir o popup atual num `PanelWindow` temporário com `grabFocus: true`.
  O Quickshell/Wayland recusou o popup porque o painel ainda não havia recebido
  entrada (`Failed to create grabbing popup`); desligar o foco mostra o popup,
  mas não valida foco nem interação. O harness foi encerrado e o serviço
  instalado permaneceu ativo. Não iniciei atualização nem alterei preferências.
- Portanto, a interação real requer testar a versão atual na instância instalada
  com entrada local, ou uma revisão automatizada que gere eventos no Wayland;
  as capturas com foco desativado continuam sendo somente revisão visual.

### P0-01 — acesso ao resultado persistido (2026-11-08)

- Revisão do código encontrou que `UpdateControl.available` considerava apenas
  contagem e execução. Depois de uma atualização bem-sucedida com zero pendências,
  o shell restaurava o resultado em `UpdateState`, mas escondia a pill que abre
  o popup; assim, o usuário não podia consultar novamente o resultado/log.
- `UpdateControl` agora também permanece disponível quando há resultado salvo;
  quando não há pendências, cor e tooltip indicam sucesso/falha e mostram a
  mensagem. `tests/qml/tst_update_availability.qml` cobre os quatro estados e
  `./scripts/validate.sh --offline` passou com 17 OK, 0 WARN/FAIL e QML 136/136.
- O pacote `0.1.0-14` instalado contém a correção; o serviço iniciou e
  `./scripts/visual-check.sh` passou com layer-shell e barra de 37 px. A captura
  recortada `/tmp/lume-bar-v14.png` confirma a pill visível na barra. Ainda falta
  abrir o popup e testar fechar/reabrir com entrada real.

### P0-04 — verificação após reiniciar o shell (2026-11-08)

- A primeira sondagem após `systemctl --user restart lume-shell.service` ocorreu
  antes de a barra ser mapeada e reportou ausência de layer-shell, embora a
  unidade já estivesse ativa. Após dois segundos, a mesma verificação passou.
- `visual-check.sh` agora espera até cinco segundos pela camada quando a unidade
  está ativa. `tests.test_visual_check` reproduz duas respostas vazias seguidas
  do compositor e confirma sucesso após a terceira consulta.

### P1-06 — aplicação de tema em runtime (2026-11-08)

- `theme-manager.py get` reporta Chameleon e os 11 adaptadores como sincronizados.
  GSettings do usuário retorna `gtk-theme='chameleon'` e `color-scheme='prefer-dark'`;
  o `settings.ini` GTK3 e CSS libadwaita usam o mesmo fundo `#151218` e acento
  `#d2bcfd`. Essa primeira verificação confirmou a configuração, sem ainda
  confirmar pixels numa janela GTK real.
- Iniciei um servidor Kitty headless/oculto com a configuração real do usuário
  e consultei `kitten @ get-colors`: os valores efetivos foram `background
  #151218`, `foreground #e7e0e8`, `cursor #d2bcfd` e a paleta ANSI esperada.
  O processo e o socket temporários foram encerrados/removidos. É verificação de
  configuração efetivamente carregada, sem captura de renderização.
- Hyprland ativo retorna `general:col.active_border = eed2bcfd` e
  `general:col.inactive_border = 88151218`, correspondentes às cores Chameleon
  com alpha. Não alterei opções do compositor.
- Ainda não conferido visualmente: GTK4/libadwaita, adaptadores labwc/Mango e
  reload de aplicações já abertas. Em 2026-11-08, `python3 -B -m unittest
  tests.test_theme` passou com 41 testes; Zenity emitiu aviso de accessibility
  bus e não virou janela ativa no Hyprland, então não houve screenshot e isso
  não conta como revisão visual. `./scripts/validate.sh --offline` passou com
  17 OK, 0 WARN/FAIL e QML 136/136.
- Depois, um cliente GTK3 mínimo foi renderizado em Labwc headless/Pixman com
  `GDK_BACKEND=wayland` e cópias temporárias das configurações do usuário. A
  captura `/tmp/lume-p1-gtk-chameleon.png` mostra conteúdo escuro, rótulo claro,
  campo e botão; a amostra do fundo da janela é `#151218`, igual ao CSS ativo.
  Isso confirma a paleta no conteúdo GTK3. A decoração cinza da janela pertence
  ao tema padrão do Labwc; não validei GTK4/libadwaita nem reload de app aberta.

### P1-03 — erro do clima (2026-11-08)

- Harness Wayland com `WeatherCard` da árvore de trabalho, previsão válida em
  cache (`stale: true`) e timeout simulado. A captura
  `/tmp/lume-p1-weather-error.png` confirma que temperatura, previsão e selo de
  dado antigo continuam visíveis; a falha aparece em vermelho, truncada para
  caber na linha.
- Hover sobre a linha exibiu o diagnóstico completo em
  `/tmp/lume-p1-weather-tooltip.png`. Cursor restaurado à posição anterior e
  harness encerrado após a captura. Nenhuma consulta externa foi iniciada.
- `./scripts/test-quickshell-processes.sh`: passou. `./scripts/validate.sh
  --offline`: 17 OK, 0 WARN, 0 FAIL; QML 130/130. P1-03 concluído.

### P1-04 — pausa da captura do clipboard (2026-11-08)

- `python3 -B scripts/test-clipboard-wayland-isolated.py` passou contra Labwc
  headless: sentinel colocado durante a pausa não entrou no histórico; após
  retomar, a próxima seleção foi capturada. Socket, seleção e XDG foram isolados
  em temporário; o teste limpou somente a seleção de teste ao encerrar.
- Harness visual do `ClipboardPreview` com store controlado mostra os dois rótulos:
  `/tmp/lume-p1-clipboard-capturing.png` (Pausar) e
  `/tmp/lume-p1-clipboard-paused-control.png` (Retomar). Essas capturas verificam
  o estado renderizado; a integração headless separada valida o efeito real na
  persistência quando a seleção Wayland muda.
- O harness foi encerrado; nenhuma seleção ou dado do clipboard ativo foi usado.
  P1-04 concluído.

## Barra

- [ ] Altura/zona exclusiva seguem `barHeight` (37); recuo `barPanelInset` (3).
- [ ] Pills seguem `pillHeight` (25), `pillRadius` (8) e alinhamento vertical.
- [ ] Três ilhas principais e ilhas condicionais de Submap/Spotify mantêm espaço.
- [ ] StartButton/Workspaces, centro Weather/Clock e ordem à direita seguem Bar.qml.
- [ ] Network continua após Tray no código; Network/Bluetooth ocultos mantêm
  detalhes via Quick Settings. Não esperar Phone na barra atual.
- [ ] Printer, gravação, monitor, bateria, áudio, indicadores, atualizações e
  notificações não colidem quando contagens e textos crescem.
- [ ] MediaIsland só aparece com Spotify/título e espaço disponível; clique e
  play/pause funcionam. Hover preview legado só é verificado se estiver em uso.
- [ ] Áudio mantém scroll de volume, clique para detalhes e botão direito para mute.

## Dashboard e atualizações

- [ ] Dashboard tem clima e calendário/feriados; hardware está em SystemMonitor.
- [ ] SystemMonitor aparece na barra, mostra percentual de CPU e abre os quatro
  dados do popup sem cartões internos concorrentes ou cortes de conteúdo.
- [ ] Cidade, estado de atualização e previsão antiga/erro ficam compreensíveis.
- [ ] Calendário: destaque, data, progresso anual e feriados concordam após
  abertura, virada de dia/mês/ano e retomada de suspensão.
- [ ] Navegação de mês e retorno a hoje preservam a intenção do usuário.
- [ ] Largura reduzida usa a rolagem/paginação prevista no dashboard sem cortes.
- [ ] Atualizações têm pill e popup próprios; estados vazio, carregando, etapa,
  sucesso e falha não são confundidos.
- [ ] A ação do log permanece após o fim da atualização e reabertura do shell;
  terminal ou arquivo indisponível mostra diagnóstico compreensível.
- [ ] Conferir pacote expandido + execução + mensagem longa; botões acessíveis.
- [ ] Conferir acesso ao resultado quando a contagem chega a zero e após reinício
  do shell, inclusive com log no fallback de `/tmp`.

## Quick Settings e dispositivos

- [ ] Notificações abrem o painel combinado com áudio, brilho, rede, Bluetooth,
  DND, inibição, night light, mídia e sessão; atualizações ficam no popup próprio.
- [ ] Detalhes de rede/Bluetooth abrem no owner correto após fechar o painel.
- [ ] Rede: conexão ativa, lista, senha, QR e speedtest mantêm seus contratos.
- [ ] NetworkPopup: vetores temáticos e hierarquia de superfícies; conferir
  ativo, ocupado, erro, portal, QR, senha visível e speedtest sem cortes.
- [ ] Bluetooth: desligado, buscando, conectado, pareado e bateria legíveis.
- [ ] Áudio: sliders compartilhados de saída, entrada e streams; mute e seleção
  de dispositivo mantêm ação e feedback corretos.
- [ ] Night Light desligado/ligado: indicador e daemon concordam após reiniciar
  a sessão; desligar encerra processos residuais e restaura a gama.
- [ ] Mídia: título longo, artwork ausente, seletor e busca de posição funcionam;
  trocar player não recria estruturas de forma que cause regressões conhecidas.
- [ ] Bateria: níveis, perfil, boost e limite de carga mantêm feedback próprio.
- [ ] Popup de bateria: cores iguais às da barra inclusive durante carga; ícones
  vetoriais alinhados; perfil, boost e limite seguem acionáveis e sem corte.
- [ ] Impressora: acessível com jobs mesmo se a sondagem falhar; fila e cancelamento
  corretamente representados, sem executar cancelamento real só para validar UI.

## Spotlight

- [ ] Campo focado, setas, Enter e Escape por camada de navegação.
- [ ] StartButton e Super+D abrem o mesmo launcher; categorias e prefixos funcionam.
- [ ] Largura padrão 560; clipboard 820×500; outros modos seguem suas dimensões
  em Spotlight.qml, inclusive tema, ações e emoji.
- [ ] Theme Studio: cores do wallpaper ativo, foco/Tab/Shift+Tab, hover sem
  aplicação, prévia escuro/claro/OLED, cancelar e aplicar; conferir rolagem,
  contraste e troca do wallpaper durante geração.
- [ ] Clipboard permite até 200 itens; busca, seleção por ID, preview e ações
  funcionam; Enter restaura ao clipboard sem pressupor colagem automática no app.
- [ ] Clipboard: pausa/retomada de captura tem estado visível, persiste ao
  reiniciar o shell e só grava seleções copiadas após retomar; erro de gravação
  fica visível e o controle funciona por teclado.
- [ ] Ícones/tipografia seguem as escalas spotlight; seleção usa pares de tokens.
- [ ] Texto longo acessível no preview; imagem mantém proporção; roda usa convenção.
- [ ] Informações do Sistema fecha por Escape e não por clique fora.

## Notificações e OSD

- [ ] Toast usa PopupCard e tokens de movimento; distinguir abertura do swipe.
- [ ] Margens atuais do toast: topo 45; borda direita alinhada à ilha direita
  da barra (recuo do painel + espaçamento médio do tema).
- [ ] Timer normal 5.500 ms, baixa urgência 3.500, crítico sem expiração automática;
  hover pausa timer; notificações vazias filtradas e DND preservado.
- [ ] Entrada curta desce do topo com fade; saída crítica e normal move à direita;
  cartões existentes não deslizam; camada mantém geometria e cliques passam fora
  dos cartões.
- [ ] Histórico mantém viewport e rolagem existentes, limpar/DND e estado vazio.
- [ ] OSD aparece sem tomar foco; volume, microfone e brilho mantêm valores e
  duração por evento; não impor duração universal a todos os tipos.

## Critérios transversais

- [ ] Cores vêm do tema ativo; conferir paletas clara/escura/OLED quando afetadas.
- [ ] Medir contraste sobre o fundo composto; meta 4,5:1 para texto normal.
- [ ] Seleção, hover, foco, erro e desabilitado visualmente distintos.
- [ ] Rótulos próprios essenciais sem corte; conteúdo variável com texto completo
  acessível em detalhe/preview/tooltip quando houver elipse.
- [ ] Teclado: ordem de foco, Tab/Shift+Tab, Enter/Espaço, setas e Escape aplicáveis.
- [ ] Ancoragem no monitor correto; bordas, escala fracionária e área pequena.
- [ ] Cliques fora e retorno de foco respeitam exceções, não uma regra universal.
- [ ] Layout fica dentro da área útil com lista longa, vazio, erro e estado ocupado.
- [ ] Movimento usa tokens; fechamento visual e ocultação da janela coordenados.
- [ ] Política atual por compositor preservada; não presumir blur universal.
- [ ] Verificações estáticas e logs sem erros relevantes; evidências visuais e de
  interação registradas separadamente.

### Regressão — workspace ocupado não exibido, 06/11/2026

- Reproduzido no host: `hyprctl workspaces -j` reportou workspace 3 com uma
  janela; a barra o omitia, e o log do Quickshell informou que recebeu
  `openwindow` para um workspace ainda não rastreado. Reiniciar o serviço sem
  a correção não alterou o resultado.
- A barra agora considera a contagem `windows` do snapshot do Hyprland junto aos
  toplevels rastreados e atualiza o snapshot após abrir, fechar ou mover janelas.
- Três casos da função de ocupação passaram em execução isolada com Node. O
  `qmltestrunner` e o `qmllint` locais encerraram sem diagnóstico; a captura
  visual após reinstalação ficou inconclusiva porque uma janela fullscreen
  cobria a barra. Repetir a verificação visual com a barra visível.

### Evidência — ícones da barra, 24/10/2026

- Sessão ativa: `/tmp/bar-vector-refinement.png`; busca, workspaces 1/2/3/5,
  clima, data/hora, rede, atualizações, gravação, bateria carregando, som e
  controles visíveis, centralizados e sem sobreposição.
- Quickshell recarregado com `Configuration Loaded`, sem erros QML na captura.
- `./scripts/validate.sh`: 29 OK, 0 WARN, 0 FAIL; inclui 101 testes QML e
  todos os testes unitários. 40 arquivos SVG verificados como XML válido.
- Mantida geometria das ilhas e ações existentes. Rotação das atualizações
  aplicada ao conteúdo vetorial da pill.
- Pendentes: outras escalas, paletas e monitores; impressão, VPN, submap,
  workspaces 4/6–10 e transporte de mídia sem cenário ativo para captura.

### Implementação — popup central da data, 24/10/2026

- Clima e calendário passaram a compartilhar a superfície principal do popup;
  tiles de métricas meteorológicas continuam agrupados por contexto.
- Ícones locais substituem os glifos da localização, setas do calendário,
  ações de cidade, símbolos meteorológicos, métricas e horário de atualização.
- Temperatura principal e recuos usam tokens próprios do tema.
- Validação da configuração e captura visual do popup aberto permanecem
  pendentes nesta etapa; os comportamentos de calendário e cidades foram
  preservados no código.
