# Plano de consistência visual do shell

## Prioridade para agentes

Este é o plano ativo e prioritário do projeto, conforme instrução do usuário.
Sua leitura é obrigatória antes de escolher ou implementar mudanças no shell;
o contrato de execução está em [AGENTS.md](../AGENTS.md#active-plan-priority).
Pedidos explícitos do usuário definem o escopo. Dentro dele, atender primeiro
à fase aplicável mais antiga ainda pendente. Em melhorias abertas, este plano
precede roadmaps antigos, polimento opcional e refatorações propostas pelo agente.
Atualizar o andamento com evidências; implementação sem verificação dos critérios
não equivale a fase concluída. Preservar os contratos estáveis.

## Base da revisão

### Hyprlock — 28/10/2026

A configuração externa aproxima o campo de senha das ilhas de vidro do shell,
com tokens exportados pelo adaptador de tema, tipografia Noto Sans e recuos
revisados. Detalhes em [system-setup.md](system-setup.md#hyprlock-appearance).
A avaliação visual no próximo bloqueio permanece pendente.


### Extensão: Cores do wallpaper (implementada; composição revisada)

O usuário solicitou o planejamento da escolha de cor principal a partir do
wallpaper. O [plano do Theme Studio](wallpaper-color-plan.md) define a experiência,
integração e critérios de aceitação. A extração, prévia isolada, persistência por
imagem, aplicação explícita e controles de teclado já foram implementados; os
composição recolhida/expandida foi revisada no shell após feedback do usuário;
a matriz completa de contraste e variantes continua pendente.
Agentes que alterarem temas, extração de cores ou a galeria devem consultá-lo.
Na implementação dessa extensão, seguir suas etapas 1 → 2 → 3 e aplicar os
critérios transversais deste plano. A ordem das fases gerais permanece válida para melhorias abertas.

### Ajuste do Theme Studio — 23/10/2026

Após feedback de incompatibilidade com o estilo do shell, a revisão usa abas
horizontais compactas, seleção tonal e preview com wallpaper. A altura circular
da janela foi corrigida; geometria usa conteúdo e limite da tela. Captura da
sessão ativa: `/tmp/theme-studio-style-after.png`. Validação automatizada no host: 29 OK, 0 WARN, 0 FAIL, incluindo 101 testes
QML. Temas e navegação por Tab para Wallpaper inspecionados na sessão; matriz
de variantes e escalas continua pendente.

### Referência da auditoria

Auditoria documental de 22/10/2026. Base: commit `c287c0b` e alterações locais
já presentes de calendário e progresso de atualizações. Evidências: arquivos
listados abaixo e screenshot `20261022_110942.png` do dashboard. A captura ajuda
na leitura do calendário; não demonstra a aparência de todos os popups, paletas
ou compositores. Nenhuma etapa futura está marcada como validada visualmente.

## Resultado desta revisão

O [guia de design](design-guidelines.md) concentra a linguagem visual e os
contratos; o [checklist](visual-regression-checklist.md) concentra a aceitação.
O mapa de composição permanece em [current-state](current-state.md), e detalhes
funcionais permanecem nos documentos de domínio. Esta entrega corrige a
orientação documental. As mudanças de código abaixo são um plano de execução.

### Contradições resolvidas na documentação

| Orientação anterior | Evidência no código | Resolução |
| --- | --- | --- |
| Clipboard mostra 50 itens | `launcher/SpotlightClipboard.qml`, `SpotlightQueryRouter.qml`: 200 | Guia e checklist usam 200; retenção separada em 500 |
| Enter cola automaticamente no app | `scripts/launcher-data.py:clipboard_restore`, `clipboard_store.py:restore_item` | Documentar restauração via wl-copy; não prometer Ctrl+V |
| Três ilhas e Submap dentro da esquerda | `bar/Bar.qml`: superfícies próprias de Submap e MediaIsland | Três principais + duas condicionais |
| Bluetooth/Phone visíveis na barra | `bar/Bar.qml`: Bluetooth oculto, Phone ausente | Diferenciar componente montado, widget visível e código legado |
| Atualizações no calendário/Quick Settings | `bar/UpdateControl.qml`, `bar/Bar.qml` | Popup dedicado; dashboard com clima/calendário |
| Mocha e hex fixos como regra de todas as paletas | `Theme.qml`, `services/ThemeState.qml` | Mocha como referência; tokens adaptativos como contrato |
| `theme.onSurface`, `onPrimaryContainer`, `onErrorContainer` | `Theme.qml` expõe `surfaceForeground`, `primaryContainerForeground`, `errorContainerForeground` | Documentar nomes reais da API QML |
| Pill com raio 6 no checklist e 8 na tabela | `Theme.qml:pillRadius` = 8 | Consumir token; remover especificação contraditória |
| Moldura própria obrigatória em cada pill | `components/Pill.qml:plain`, `bar/Bar.qml` | Pills internas às ilhas usam modo plain |
| Todo popup só faz fade simétrico | `components/PopupCard.qml`: escala + deslocamento + opacidade; tempos 200/150 | Descrever estado atual; futura mudança global exige escopo próprio |
| Toast desliza do canto e expira em 5 s | `notifications/NotificationToasts.qml`: PopupCard, timer por urgência | Separar abertura de swipe de dispensa; registrar tempos reais |
| Qualquer clique fora fecha qualquer janela | `launcher/SystemInfoPopup.qml`, Spotlight, fila desktop | Contratos por superfície; SystemInfo fecha por Escape |
| Nenhum texto pode usar elipse | `MediaIsland.qml`, delegados de listas e mídia | Rótulos próprios curtos; conteúdo variável tem elipse e acesso ao completo |
| MouseArea obrigatório | componentes usam TapHandler/HoverHandler e MouseArea | Exigir feedback e teclado, sem impor um único handler |
| Sliders de áudio não são compartilhados | `bar/AudioPopup.qml` usa `SliderRow` | Corrigir arquitetura e manter ações de mute/roteamento no domínio |
| Rede/Bluetooth sempre ancorados em suas pills | `bar/Bar.qml:popupTarget` aponta à pill de notificações | Descrever acionador/owner real |
| Mídia montada abre sempre no hover | `bar/MediaIsland.qml` abre por clique; legado `Media.qml` usa hover | Preservar ambos sem confundir qual está montado |
| Dimensões do Spotlight universais e fórmula antiga | `launcher/Spotlight.qml:centerAnchor/card`: larguras por modo | 560 padrão, 820 clipboard; demais modos consultam o código |

## Princípios para executar

Tratar cada fase como mudança pequena e revisável. Não redesenhar mídia, áudio,
OSD ou notificações estáveis para uniformizar aparência. Antes de cada mudança,
registrar estado anterior, cenário de reprodução e resultado esperado. Evitar
constantes duplicadas em documentos; atualizar o guia apenas quando mudar o
contrato, e o documento de domínio quando mudar o comportamento.

## Fase 0 — Documentação coerente (concluída nesta revisão)

- [x] Reescrever o guia com tokens existentes, estado atual e critérios futuros.
- [x] Atualizar o checklist e o mapa da barra.
- [x] Corrigir os trechos conflitantes de arquitetura, controle central e
  contrato de estabilidade; esclarecer a referência Catppuccin em AGENTS.md.
- [x] Registrar divergências com fontes e critérios de aceitação.

Aceitação: links locais válidos, nomes QML do guia conferidos em Theme.qml,
nenhuma mudança de runtime necessária para usar os documentos.

## Fase 1 — Estado e acesso a diagnóstico (prioridade alta)

**Objetivo:** informação correta e ações acessíveis durante mudanças de estado.

1. Calendário (`CalendarCard.qml`): revisar a correção local de data reativa em
   virada de dia, mês, ano e retomada de suspensão. Conferir destaque, cabeçalho,
   ano e countdown dos feriados; o cabeçalho usa `shownDate`, que pode permanecer
   antigo se o popup ficar aberto durante a virada. Definir a atualização quando
   se está vendo hoje, preservando um mês navegado intencionalmente.
2. Atualizações (`SystemUpdatePopup.qml`, `UpdateState.qml`, `UpdateControl.qml`):
   conferir layout com pacote expandido + atualização em curso. A altura atual
   usa `showPackages ? 536 : ...`, sem compor todos os estados; é um risco de
   corte a reproduzir, não um defeito visual já confirmado.
3. Revisar “Ver progresso no terminal”: atualmente só aparece durante execução
   e a pill só permanece com contagem positiva ou execução. Garantir acesso a
   resultado/erro após término e reinício, incluindo ausência de log e fallback
   do backend para `/tmp`. Hoje UI e backend calculam o caminho separadamente.
4. Encaminhar a abertura do log por uma ação do domínio em `UpdateState` ou helper
   existente, com erro visível; evitar a UI decidir processo, terminal e cache.
   Não iniciar outra atualização ao abrir o diagnóstico.

Aceitação: cenário de virada não deixa datas contraditórias; painel de
atualização não corta botões em combinações de estados; erro e log permanecem
acessíveis; fechar o terminal não interfere no processo de atualização.
Usar relógio/dados controlados e comandos simulados para cenários de falha;
não instalar pacotes ou mudar o relógio real para testar.

## Fase 2 — Legibilidade e teclado (prioridade alta; após fase 1)

**Objetivo:** controles compactos legíveis e acionáveis por ambos os meios.

- Auditar primeiro atualizações, calendário e cabeçalhos de popups; depois
  rede/Bluetooth, notificações e Spotlight.
- Medir texto normal/selecionado/desabilitado no tema ativo e em Chameleon
  claro/escuro/OLED, com wallpapers claros e escuros. Inventariar usos de `grey`
  em texto pequeno; substituir por papel adequado onde a medição justificar.
- Verificar ordem de foco, foco visível, Tab/Shift+Tab, Enter/Espaço e Escape.
  O botão novo do terminal usa somente TapHandler e precisa dessa revisão.
- Revisar rótulos de ações cortados e oferecer acesso ao texto integral dos
  conteúdos variáveis. Não aumentar toda a interface para corrigir um rótulo.

Aceitação: texto normal com meta de 4,5:1 nas combinações medidas; seleção
visível sem depender só da cor; ações novas acionáveis por teclado, sem roubar
foco de outra janela. Registrar resultados por superfície e paleta.

## Fase 3 — Componentes e movimento (prioridade média)

**Objetivo:** reduzir divergências sem alterar os contratos estáveis.

- Inventariar cabeçalhos, botões, linhas e estados vazios feitos manualmente;
  migrar somente casos realmente cobertos pelos componentes compartilhados.
- Corrigir primeiro duplicações tocadas pelas fases 1/2. Ações de domínio ficam
  fora dos componentes visuais genéricos.
- Revisar conjuntamente PopupCard, visibilidade das janelas e timers de remoção
  de toasts: os tempos atuais são diferentes e ocultação imediata pode impedir
  a animação de saída. Verificar antes de mudar o contrato de movimento.
- Propor uma configuração de movimento reduzido em MotionState; atualmente
  `qmlAnimationsEnabled` é constante true. Preservar feedback de estado quando
  animações estiverem desativadas.

Aceitação: mesmos atalhos, foco, ancoragem e conteúdo antes/depois; sem dupla
animação ou saída interrompida nos cenários medidos; componentes compartilhados
com consumidores reais. Decisões de movimento atualizam guia e checklist juntos.

## Fase 4 — Geometria e matriz de regressão (prioridade média)

**Objetivo:** comportamento previsível com conteúdo e telas diferentes.

- Comparar tela principal e segunda tela, menor área disponível, escala 100%
  e uma escala fracionária disponível. Medir a área útil em pixels lógicos.
- Conferir cinco ilhas possíveis, ocultação da MediaIsland por falta de espaço,
  crescimento dos indicadores e colisões entre centro e direita.
- Conferir listas vazias/longas, mensagens longas, maior quantidade de áudio
  por aplicativo e pacote expandido. Priorizar altura por conteúdo com limite
  da tela e rolagem, mantendo ações acessíveis.
- AudioPopup: a captura `Imagens/Screenshots/20261027_151600.png` confirmou
  conteúdo do mixer desenhado para fora do popup. A altura agora acompanha o
  conteúdo até o limite da tela e oferece rolagem interna; validação visual
  após a alteração ainda pendente.
- Repetir os cenários afetados em Hyprland e, quando disponíveis, Mango e labwc;
  registrar como pendente qualquer compositor sem sessão para inspeção.

Aceitação: sem sobreposição, cortes de ação ou popup fora da área útil;
Network continua após Tray; foco/dispensa corretos por superfície; mídia e
áudio estáveis mantêm aparência e comportamento.

## Entrega e acompanhamento

Cada fase entrega implementação, documentação de domínio e evidências no
checklist. Executar verificações proporcionais à mudança e o validador do
projeto antes de publicar código; registrar limitações do ambiente. Screenshots
sozinhos não provam foco, teclado, contraste ou comportamento após suspensão.
Não considerar esta revisão uma validação completa do shell.

Ordem de prioridade: fase 1 → fase 2 → fase 3 → fase 4. A prioridade imediata é
concluir calendário e acesso ao progresso das atualizações antes de refinar
estética global. Commit/push e alterações funcionais futuras são etapas
separadas da presente revisão documental.

### Barra inspirada na referência — 23/10/2026

Pedido específico: preservar a ilha de mídia e o relógio central; aproximar o grupo direito da referência. Implementados lua de DND, rede neutra, bateria horizontal com preenchimento proporcional e número integrado, lupa e controles com marcador de notificações. CPU e áudio ficam acessíveis pelo painel. Verificação visual inicial na sessão ativa: `/tmp/quickshell-bar-after.png`; sem concluir a matriz geral de escalas e paletas.

Refinamento da bateria: desenho horizontal com preenchimento proporcional, raio durante carga e cores semânticas para carga baixa; valor exato no tooltip/popup. Captura final: `/tmp/quickshell-battery-icon.png`. Configuração recarregada com sucesso na sessão; painel inspecionado em `/tmp/quickshell-controls-after.png`. Validador no host: 28 OK, 0 WARN, 1 FAIL por três cores literais preexistentes em `launcher/ThemePreviewPane.qml`; testes unitários e 101 testes QML passaram.

Ajuste após feedback de proporção: bateria reduzida de 25×12 para 20×10 px, cantos de 2 px e preenchimento com margem interna de 2 px. Recarregamento confirmado e proporção inspecionada em `/tmp/quickshell-battery-balanced.png`.

Ajuste de escala dos indicadores: Wi-Fi, DND, busca e controles passaram de 11 para 14 px para equilibrar a bateria de 20×10 px. Recarregamento confirmado; captura: `/tmp/quickshell-icons-balanced.png`.

Escala geral da barra: ícones em pills, workspaces e transporte de mídia agora usam o token `iconTokens.lg` (14 px); tray já usava 14 px. Texto de metadados da ilha de mídia permanece nas escalas próprias.

A pill de atualizações agora mostra somente o ícone; quantidade e progresso detalhado continuam no tooltip/popup.

O ícone de atualizações disponíveis agora é uma seta de envio/instalação desenhada no conjunto Tabler local; durante a execução, a pill mantém o ícone de sincronização.

A lupa à esquerda agora ancora pelo centro vertical da ilha junto aos workspaces; alinhamento conferido em `/tmp/quickshell-search-aligned.png`.

O acionador do Spotlight na barra continua com seu glifo original e abre a busca.

A lupa dentro do campo do Spotlight agora usa o desenho vetorial Tabler `search.svg`, com círculo e haste de traço contínuo. Inspecionada com o launcher aberto em `/tmp/quickshell-spotlight-search-tabler.png`.

Ajuste visual do percentual integrado: contorno neutro, trilha discreta e cor semântica somente no preenchimento; número usa contraste conforme esteja sobre a carga preenchida ou a trilha. Conferido em `/tmp/quickshell-ios-battery-refined.png`.


### Bateria: raio integrado — 24/10/2026

Refinamento solicitado, relacionado à legibilidade (fase 2) e geometria (fase 4):
raio vetorial e percentual pesado centralizados em conjunto, com contraste
compartilhado sobre o preenchimento e espaço adicional durante carga. Mantidas
as cores por nível, inclusive carregando. Configuração carregada sem erros QML;
inspeção do estado de carga baixo na sessão em `/tmp/battery-ios-bar.png`.
Outras escalas, paletas e carga de três dígitos ainda não verificadas visualmente;
esta entrega não conclui a matriz geral.

### Consistência dos ícones da barra — 24/10/2026

Pedido explícito: estender o cuidado visual da bateria à barra inteira. Aplicados
vetores locais com escala comum em busca, workspaces padrão, rede/VPN, áudio,
DND, atualizações, controles, clima, relógio, impressão, gravação, submap e
transporte de mídia. Workspaces usam ícone e número semibold centralizados
separadamente. Mantidos eventos, estados, cores semânticas, ícones personalizados e composição
das ilhas. Captura `/tmp/bar-vector-refinement.png`. Validação do projeto:
29 OK, 0 WARN, 0 FAIL, incluindo 101 testes QML; 40 SVGs válidos. Impressão,
VPN, submap e transporte de mídia sem estado ativo na captura. Relacionado às
fases 2 e 4; a matriz geral permanece aberta.

### Primeira unificação do popup da data — 24/10/2026

Clima e calendário agora usam a superfície externa comum sem duas placas
internas concorrentes. Cabeçalho de localização, adicionar/buscar/remover cidade,
previsões atual e por hora/dia, métricas meteorológicas, atualizado, calendário,
retorno a hoje e navegação mensal compartilham vetores locais com traço e cor
orientados pelo tema. Recuos usam `popupInsets.standard`; temperatura principal
usa `dashboardHeroFontSize`. Estados, dados, cores semânticas, ações, atalhos e
layout responsivo foram preservados. Recarga QML confirmada; inspeção da própria
janela aberta, paletas e telas compactas ainda pendente.

### Unificação do popup de bateria — 24/10/2026

O popup adotou ícones vetoriais tintados para bateria, tempo e CPU, reutilizando
`SettingToggleRow` sem remover consumidores existentes. Cabeçalho usa o estado
compartilhado com a barra; níveis vermelho (≤15%), amarelo (≤35%) e verde (>35%)
são iguais aos do indicador, inclusive durante carga. Controles e hierarquia
de métricas foram preservados. Validação QML e inspeção visual da janela aberta
ainda pendentes.

### Percentual da bateria durante carga — 24/10/2026

O limite do preenchimento não corta mais os glifos do percentual e do raio. A
camada de preenchimento é independente; número e raio são desenhados uma vez,
com tinta em gradiente na fronteira da carga. A captura recortada
`Imagens/Screenshots/20261024_135728.png` motivou a correção original; a captura
`Imagens/Screenshots/20261027_153300.png` revelou que a transição estreita pode
dar aparência de desalinhamento entre dígitos adjacentes. A faixa de transição
foi ampliada para suavizar esse corte; inspeção visual após a mudança pendente.

### Retorno e unificação do monitor do sistema — 24/10/2026

O indicador compacto de CPU voltou à ilha direita, preservando o acesso ao
popup pelo painel de notificações. A pill é apenas o ícone de CPU; cor semântica
sinaliza carga elevada e o tooltip conserva o percentual exato. O popup mantém a moldura única, remove
cartões aninhados das métricas, usa divisores discretos e vetores locais
tintados pelo tema para CPU, memória, temperatura e ventoinha. Verificação QML,
sensores ativos e inspeção visual do popup ainda pendentes.

### Unificação do popup de rede — 24/10/2026

Cabeçalho, sinal Wi-Fi, Ethernet, busca, portal, latência, tráfego, speedtest,
QR, segurança e visibilidade da senha usam vetores tintados pelo tema. A moldura
principal continua única; grupos de portal, telemetria, teste e QR permanecem
por tarefa, enquanto as redes e VPNs mantêm interação e estados existentes.
Validação automatizada e revisão visual/interativa ainda pendentes.

### Notificações: desempenho e movimento — 26/10/2026

Pedido explícito relacionado à fase 3: toasts com modelo de chaves estáveis,
entrada lateral curta, saída sincronizada e deslocamento da pilha sem recriar
cartões existentes. Imagens têm decodificação limitada e o histórico desmonta
seus delegados quando fechado. Configuração carregada na sessão; captura
`/tmp/quickshell-notification-check.png`. Validação e limites de diagnóstico em
`docs/notifications.md`; medições prolongadas de memória e frame time pendentes.

### Superfícies glass da shell — 27/10/2026

Unificada a translucidez da barra e dos fundos de popup pelo token `background`,
com teto de alpha 0,68 no Hyprland; labwc/Mango preservam o fallback opaco sem
blur. A regra de layer existente cobre a barra e blur de popups, e o raio global
do compositor foi aumentado de 10 para 14. Quickshell recarregou sem erros,
Hyprland aceitou a configuração e `scripts/validate.sh` passou (29 OK, 0 WARN,
0 FAIL). A captura pós-ajuste ficou sob uma janela opaca, então a inspeção visual
do blur no wallpaper e a legibilidade com wallpapers claros/outros compositores
continuam pendentes.

### Foco inicial no wallpaper do Theme Studio — 27/10/2026

Ao entrar no modo de temas do Spotlight, a navegação interna agora começa na
galeria e sincroniza a seleção ao wallpaper ativo. O foco Qt continua no campo
de busca para preservar a edição e o roteamento de teclas. Captura de sessão
`/tmp/quickshell-theme-wallpaper-arrow.png` confirma o contorno e a navegação
por setas na galeria, sem realçar o cartão do tema ativo como foco. Quickshell
recarregou sem erros; `scripts/validate.sh` passou (29 OK, 0 WARN, 0 FAIL).

### Bateria Material 3 Expressive — 01/11/2026

Pedido específico, relacionado às fases 2 e 4: corpo retangular arredondado,
percentual maior com baseline única e símbolo de estado externo. O preenchimento usa verde durante carga; o raio usa o primeiro plano do
tema. Após feedback, o perfil Economia fica apenas no popup, sem alterar a
cor ou acrescentar “+” à pill. Detalhes e
referências em [power-controls](power-controls.md#bar-indicator).
Recarga confirmada e estado real de 77% em Economia inspecionado em
`/tmp/battery-android.png`. Carga, 100%, bateria baixa, tema claro e escala
fracionária permanecem pendentes; esta entrega não conclui a matriz geral.

Validação no host: 29 OK, 0 WARN, 0 FAIL; 107 testes QML aprovados.

Refinamento do raio conforme referência ampliada: silhueta de 12×14 px,
miolo mais largo e cantos suavizados. Percentual e estados preservados.

Após feedback, o raio foi simplificado para um polígono de seis vértices,
sem curvas, centralizado na mesma área externa. QML validado.
