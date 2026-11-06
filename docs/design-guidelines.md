# Guia de design do shell

Referência revisada em 22/10/2026 a partir de `Theme.qml`, das superfícies
montadas e dos componentes compartilhados. Este guia define decisões para
novas mudanças; os valores descritos como **atuais** registram a implementação
observada, sem declarar que toda a interface já passou por auditoria visual.

## 1. Fontes e precedência

- Instruções explícitas do usuário prevalecem sobre este documento.
- [Contrato de estabilidade](stability-contract.md): comportamentos que uma
  mudança de design deve preservar.
- [Estado atual](current-state.md): mapa das superfícies montadas.
- `Theme.qml`: fonte dos nomes e valores dos tokens; não copiar uma tabela de
  cores para implementar um componente.
- Este guia: intenção visual, composição e critérios para novas mudanças.
- [Checklist visual](visual-regression-checklist.md): verificação da entrega.
- [Plano de design](design-plan.md): divergências, prioridades e trabalho futuro.

Se código e documentação divergirem, registrar a diferença com o arquivo de
origem. Descrever o comportamento atual não transforma automaticamente um
bug em regra; mudanças funcionais seguem o contrato de estabilidade.

## 2. Identidade e hierarquia

O shell é compacto, com ilhas tonais, cantos arredondados, bordas discretas e
superfícies adaptadas ao tema. A barra serve para consulta rápida; detalhes,
edição e ações secundárias pertencem aos popups ou ao Spotlight.

Catppuccin Mocha é a referência histórica e o tema escuro padrão. As paletas
instaladas e Chameleon escuro, claro e OLED são suportadas. A identidade deve
persistir ao trocar a paleta; azul, preto e transparência fixa não são regras
universais. Escuro é a preferência inicial, não uma proibição dos temas claros
já disponíveis, incluindo Catppuccin Latte.

Hierarquia recomendada: moldura → seção necessária → conteúdo/controle.
Criar uma seção quando ela separar tarefas ou grupos compreensíveis; evitar
um cartão para cada número. Seleção, hover e erro precisam ser distinguíveis.
Cor acompanha texto, ícone ou marcador; não deve ser a única indicação.

## 3. Cores e superfícies

Passar `theme` aos componentes; usar os nomes QML abaixo. Nomes Material como
`onSurface` são chaves dos dados da paleta, não propriedades de `Theme.qml`.

| Papel | Token de superfície/cor | Texto ou ícone correspondente |
| --- | --- | --- |
| Ação principal | `primary` | `primaryForeground` |
| Seleção tonal | `primaryContainer` | `primaryContainerForeground` |
| Grupo secundário | `secondaryContainer` | `secondaryContainerForeground` |
| Erro/destruição | `errorContainer` | `errorContainerForeground` |
| Conteúdo normal | `surfaceContainer*` | `surfaceForeground` |
| Descrição/metadados | superfície do contexto | `surfaceVariantForeground` ou `textMuted` |
| Estados do domínio | `green`, `yellow`, `orange`, `red` | verificar contraste sobre o fundo real |
| Seleção legada específica | `selectionAccent` | preservar o contrato da superfície |

Não usar `grey` para todo texto secundário por padrão: algumas paletas o usam
como cor discreta de decoração. A meta de contraste para texto normal é 4,5:1;
ela precisa ser medida sobre o fundo composto, inclusive com wallpaper claro.
Isso é um critério de aceitação, não uma certificação do estado atual.

- Moldura de popup: `PopupCard`, normalmente com `popupBackground` e
  `borderPopup`. Barra: `barIslandSurface` e `barIslandBorder`.
- Seção interna: `glassPanelSurface`; linhas: `glassCardSurface`; hover:
  `glassHoverSurface`. Controles tonais usam `adaptiveCardSurface` e variantes.
- `glassPanelSurface`, `glassCardSurface`, `glassHoverSurface` and
  `glassActiveSurface` follow the persisted opacity preference in `GlassState`;
  keep their base tonal hierarchy while deriving alpha through `Theme.qml`.
- Seleção tonal usa um par de cores coerente; a seleção não pode se confundir
  com hover. Não impor opacidade absoluta a todas as paletas: fallbacks
  existentes podem ter alpha e precisam da mesma verificação de contraste.
- `stateLayer(contentColor, state)` é a sobreposição de interação. Ela não
  substitui a superfície de seleção nem a mensagem de erro.
- `withAlpha()` só quando houver função distinta dos tokens prontos; não criar
  versões locais das mesmas superfícies com alphas arbitrários.
- Arte de mídia, wallpaper e imagens preservam suas cores. Ícones de apps
  preservam identidade; cores de categoria não devem competir com a seleção.

### Política por compositor

`Theme.qml` decide a opacidade: labwc impõe alpha mínimo de 0,92 à base;
`popupBackground` também tem mínimo de 0,92 no Mango. Fora do labwc,
`backgroundAlpha` tem teto de 0,68 para que o blur do Hyprland forme uma
superfície fosca visível. Não repetir essa lógica na UI. O blur depende da
superfície e do compositor: nunca presumir que ele torna texto legível.
Imagens de mídia podem ter blur próprio, separado do fundo da janela. Mudanças
nessa política exigem comparação nos compositores afetados.

## 4. Geometria, tipografia e ícones

Valores atuais de referência; a implementação deve consumir o token.

| Papel | Referência atual |
| --- | --- |
| Barra / zona exclusiva | `barHeight`: 37 px |
| Recuo da barra | `barPanelInset`: 3 px |
| Ilha | `barIslandHeight`: 31 px; raio metade da altura |
| Pill | `pillHeight`: 25 px; `pillRadius`: 8 px |
| Raios | `radiusXs/Sm/Md/Lg/Xl`: 4/8/12/16/20 px; `radiusPopup`: 26 px |
| Larguras reutilizáveis | `popupWidths.small/medium/large`: 260/340/380 px |
| Espaçamento e recuos | `spacingTokens` e `popupInsets` por função |
| Sliders | `sliderTokens.trackHeight`: 11 px; `thumbSize`: 18 px |

Uma dimensão específica de conteúdo pode permanecer local. Não forçar todo
popup a uma largura padrão nem todo botão à altura de pill. Altura disponível,
texto longo, escalas de monitor e combinações de estados precisam ser tratados.
Listas crescem até um limite e passam a rolar; ações essenciais ficam acessíveis.

- Texto de interface: `fontFamily` (Noto Sans). Ícones: `nerdFontFamily` ou
  `iconFontFamily`; usar o sistema de ícones já adotado pela superfície.
- Código, comandos e preview textual: `monoFontFamily` (JetBrainsMono Nerd Font).
  Não usar monoespaçada em toda a interface ou em toda métrica de hardware.
- `typeTokens`: body 10, subtitle 11, bodyEmphasis 12, title 13,
  titleMedium 14 e titleLarge 15 px. Caption 8 e meta 9 são compactos;
  não escolher esses tamanhos para instruções essenciais só para fazê-las caber.
- Spotlight: query/title/body/label/keycap = 18/13/11/10/9 px nos tokens
  `spotlight*FontSize`; ícones em `spotlightIconTokens`.
- Dashboard: heading/title/body/label/meta = 14/12/11/10/10 px nos tokens
  `dashboard*FontSize`. Temperatura e outras métricas grandes têm papéis próprios.
- Rótulos da interface usam frases curtas e caixa de sentença. Reescrever
  texto de autoria do shell que corte ações importantes. Conteúdo variável
  (título de música, arquivo, SSID) pode usar elipse com acesso ao texto completo
  em detalhe, preview ou tooltip; não prometer que todo texto caberá em uma linha.

### Dashboard de clima e calendário

O popup central da data é uma única superfície `PopupCard`. As colunas de clima
e calendário compartilham o fundo, borda, recuo e escala tipográfica do tema;
conteúdo auxiliar pode usar `glassCardSurface` para separar métricas sem criar
molduras completas dentro das colunas. Ações, navegação e dados de previsão
mantêm suas cores semânticas. Ícones locais seguem a mesma família vetorial e
contraste temático usada na barra; temperatura principal usa
`dashboardHeroFontSize`, demais métricas usam seus papéis `dashboard*`.

### Popup de bateria

O popup conserva a `PopupCard` como moldura única; métricas ficam em grupos
adaptativos discretos. Bateria, tempo e processador usam ícones vetoriais locais
tintados pelo tema, alinhados ao sistema da barra e do dashboard. O cabeçalho
compartilha o rótulo de estado da barra e as cores seguem os mesmos limiares,
inclusive durante a carga. Controles de perfil, limite, turbo, foco e ações
permanecem próprios do domínio de energia.

### Popup de rede

O popup usa a `PopupCard` como moldura principal. Busca, linhas clicáveis e
controles preservam superfícies e feedback de estado do tema; aviso de portal,
speedtest e QR mantêm grupos próprios por representarem tarefas distintas.
Ícones de sinal, Ethernet, transferência, busca, segurança e ações QR usam os
vetores tintados compartilhados. Status ativo, conectado, ocupado e erro seguem
as mesmas cores semânticas dos outros popups.

## 5. Barra e distribuição das tarefas

`bar/Bar.qml` mantém composição explícita, sem `bar.json` ou ordenação por Loader.
Há três ilhas principais e até três condicionais:

| Região | Composição atual |
| --- | --- |
| Esquerda | StartButton e Workspaces |
| Após a esquerda | Submap em ilha própria, quando aplicável |
| Centro | Weather, separador e Clock; abre clima/calendário |
| Entre centro e direita | MediaIsland para Spotify e StatusIsland (Não Perturbe, inibição de suspensão e gravação em andamento), com prioridade de espaço para StatusIsland |
| Direita | Tray → Network → Bluetooth → Printer → SystemMonitor → UpdateControl → Battery → Audio → NotificationControl |

`Network` e `Bluetooth` são autônomos na barra (assim como `Audio`), exibindo
seu próprio `Pill` com ícone vetorial Tabler e ancorando `NetworkPopup` e
`BluetoothPopup` diretamente no próprio indicador. `Network` permanece logo após
`Tray` no código. `ScreenRecording` fica oculto na barra enquanto `StatusIsland`
exibe a gravação em andamento. Phone e `QuickStatusIndicators` não estão montados
em `Bar.qml`. Atualizações têm popup próprio. As pills dentro das ilhas usam
`plain` para evitar molduras duplicadas.

Não atribuir a todos os widgets as mesmas ações de botão direito ou scroll.
Preservar as ações específicas: áudio usa scroll para volume; relógio tem ação
de inibição; bandeja encaminha eventos aos aplicativos. A MediaIsland atual
abre o popup Spotify por clique, mostra capa, metadados, progresso e controles
de transporte; anterior/próxima faixa aparecem no hover. Não confundi-la com o
antigo componente `Media.qml` e seu hover preview.

## 6. Superfícies, foco e navegação

| Superfície | Contrato |
| --- | --- |
| Popup de detalhe | Ancorado ao acionador/owner real; `PopupCard`; foco ao abrir por clique; Escape e clique fora conforme contrato da superfície |
| Preview de mídia legado | Não rouba foco no hover; clicar fixa; preservar quando esse caminho for usado |
| Spotlight | Campo de busca focado; setas e Enter; Escape retorna primeiro do subestado/painel antes de fechar |
| Informações do Sistema | Exceção explícita: fecha por Escape e ignora clique fora |
| Janela de fila da impressora | Janela desktop; comportamento do compositor, não o contrato de PopupWindow |
| Toast e OSD | Feedback sem roubar o foco da tarefa atual |

Usar `PopupWindow` quando a interação é transitória e `FloatingWindow`/janela
apropriada para tarefas persistentes. `grabFocus` não é prova de dispensa correta
em todo compositor: conferir o caminho real e a tela de abertura. Não adicionar
atalho global de Escape que capture eventos de popups ocultos.

Ancoragem e margens seguem a superfície existente e `popupInsets`. Um exemplo
de âncora não garante que o conteúdo caiba na tela. Testar bordas e monitores
com escala diferente. Evitar um botão fechar redundante nos popups simples;
preservar controles de fechamento com finalidade própria em janelas e mídia.

Toda ação nova deve ter acionamento por teclado, foco identificável e rótulo
compreensível. `MouseArea` e `TapHandler` são opções válidas; cursor de ação e
feedback importam mais que impor um único tipo de handler. A cobertura atual
não é uniforme; a revisão está no plano. Tooltips usam `ToolTipBubble` e seu
atraso compartilhado, com status curto, sem repetir instruções em cada ícone.

## 7. Componentes compartilhados e rolagem

| Necessidade | Componente/API |
| --- | --- |
| Cabeçalho e ações compactas | `PopupHeader`, `PopupIconButton`, `PopupSettingsButton` |
| Lista de itens | `PopupListRow`; slots leadingIcon/title/subtitle/trailing |
| Lista com rolagem e estados | `ScrollableList`, `ScrollBar`, `EmptyState` |
| Busca/entrada | `SearchField`; foco e submissão pertencem ao domínio |
| Toggle | `MaterialSwitch`, `SettingToggleRow` |
| Volume/brilho | `qs.controlcenter.SliderRow`; mute e roteamento ficam no domínio |
| Posição de reprodução | `MediaSeekBar` |
| Erro/atividade de ação | `ActionFeedback` |
| Barra | `Pill`, `BarIslandSurface`; workspaces e tray mantêm especialização |

`PopupListRow` padrão recebe handlers em `interactionHandlers`, pois o conteúdo
padrão alternativo fica oculto. O uso incorreto pode deixar a linha sem clique.
Manter `LauncherItemDelegate`, grade de calendário e notificações especializados.
Só criar um componente quando houver reutilização concreta ou contrato comum;
não extrair uma camada sem benefício. Exceções pequenas devem explicar o motivo.
O guard `shared-ui-guard: allow` registra exceções especializadas ao verificador;
não substitui revisão de comportamento.

Rolagem convencional: roda para baixo avança/desce; para cima retorna/sobe.
Galerias horizontais mapeiam roda vertical para avançar/retornar; touchpad usa o
eixo dominante. `WheelKinetic` concentra a interação dos Flickable/ListView;
preferir `ScrollableList` para listas comuns. Grades de calendário que navegam
entre meses não são listas de rolagem. Não alterar velocidade em cada tela.

## 8. Movimento e ciclo de vida

O comportamento atual de `PopupCard` combina opacidade, escala e deslocamento;
usa `motionPopup` (200 ms), `motionPopupExit` (150 ms), `motionPopupScale` (0,97)
e `motionPopupOffset` (8 px). Toasts reutilizam PopupCard; seu tempo de remoção
usa `motionTransientFadeDuration` (210 ms). O nome desse token não significa
que a animação inteira seja só um fade. Spotlight tem seu próprio ciclo de
fechamento usando tokens compartilhados.

Preservar esse comportamento ao fazer correções locais. Reutilizar `motion*` e
`qmlAnimationsEnabled`; evitar tempos arbitrários, bounce e atraso para executar
uma ação. A resposta ao Escape começa imediatamente, mas o fechamento visual
pode concluir depois da animação. Não prometer animação de saída se a janela é
ocultada antes de ela terminar. A política de movimento reduzido é trabalho
futuro: `MotionState.qml` atualmente mantém animações habilitadas.

## 9. Estados e feedback

| Estado | Apresentação esperada |
| --- | --- |
| Carregando pela primeira vez | Texto/indicador curto; não mostrar “vazio” antes da resposta |
| Atualizando dados já conhecidos | Manter conteúdo útil; mostrar atividade sem saltos de layout |
| Vazio | Motivo curto e ação possível, quando houver; não inventar erro |
| Indisponível | Distinguir de vazio e permitir recuperação quando suportada |
| Ação em execução | Desabilitar duplicação; exibir alvo/etapa e acesso a detalhes |
| Falha | Mensagem contextual legível e tentativa/diagnóstico quando aplicável |
| Sucesso | Confirmação proporcional à ação; evitar toast redundante |

Casos concretos:

- Clipboard do Spotlight carrega e exibe até 200 itens; retenção do banco é
  outra política (500 não fixados). Enter restaura ao clipboard; o helper não
  injeta automaticamente Ctrl+V no aplicativo. Ver [clipboard](clipboard.md).
- Impressora com trabalhos no CUPS permanece acessível mesmo com falha na
  sondagem de rede. Não esconder a fila que permite diagnóstico/cancelamento.
- Calendário usa data atual reativa para destaque, progresso anual e feriados.
- UpdateControl aparece com pendências ou execução. O popup mostra etapas e,
  durante a execução, oferece o terminal de progresso. Mensagens essenciais de
  falha precisam continuar acessíveis; verificar isso no plano.
- Dashboard central contém clima e calendário/feriados. Telemetria fica no
  SystemMonitor; atualizações ficam no seu próprio popup.
- Toasts: atualmente 5,5 s normais, 3,5 s de baixa urgência e sem expiração
  automática para críticos; hover pausa o timer. OSD usa duração por evento
  (valor inicial de 1.250 ms), não um prazo universal de 1.500 ms.

## 10. Aceitação de uma mudança

Usar o [checklist](visual-regression-checklist.md) nos estados afetados, incluindo
texto longo, erro e escala de monitor. Conferir contraste com a paleta ativa e
uma variante clara/escura quando a mudança envolve cores compartilhadas.
Documentar o que foi inspecionado, o que foi executado e o que ficou pendente.
Checks estáticos não substituem inspeção visual e interação real.

Mudanças de documentação não exigem reiniciar o shell. Mudanças de UI devem
preservar contratos estáveis e passar pelas verificações descritas em
[deploy e validação](deploy-and-validation.md). Não abrir diálogos destrutivos,
atualizar pacotes ou cancelar jobs apenas para demonstrar um estado visual.

### Refinamento dos ícones da barra — 24/10/2026

Os controles da barra usam vetores locais `assets/tabler/bar-*.svg`, desenhados
para uma grade comum de 24 unidades com traço arredondado de 2 unidades e
renderizados em `barIconSize`. A cor vem dos tokens do tema. Ícones e números
padrão dos workspaces são elementos separados, centralizados verticalmente;
configurações personalizadas em `workspaces.json` continuam aceitando glifos.
Clima, data e hora separam os vetores do texto Noto Sans. Atualizações preservam
a rotação durante execução. Ícones de aplicativos da bandeja e a marca Spotify
continuam pertencendo aos aplicativos. A mudança é restrita à barra; os popups
mantêm os próprios controles e contratos.
