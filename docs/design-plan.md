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

## Estado de referência

O [guia de design](design-guidelines.md) define os contratos visuais; o
[checklist](visual-regression-checklist.md) define como registrar verificações.
Para localizar componentes, use [estado atual](current-state.md). O histórico
da auditoria, decisões antigas e notas de refinamento está em
[history/design-plan-log.md](history/design-plan-log.md).

O [plano de cores do wallpaper](wallpaper-color-plan.md) é específico do Theme
Studio. Consulte-o para mudanças nessa experiência; a matriz completa de
contraste e variantes segue pendente.

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

Concluir o item **P0-01** em [pendências técnicas](technical-todo.md): calendário
reativo, combinações de estado do popup de atualização e acesso persistente a
resultado/log. Esse backlog contém os cenários e critérios detalhados, evitando
manter duas listas de implementação. A atualização de datas do calendário agora
é função pura e simulável; ainda faltam os estados integrados do popup e a
retomada real após suspensão antes de encerrar a fase.

Aceitação e evidências: conforme P0-01 no backlog. Não instalar pacotes nem
mudar o relógio real para testar.

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

Ordem de prioridade: fase 1 → fase 2 → fase 3 → fase 4. A implementação de cada
fase deve atualizar o [backlog técnico](technical-todo.md), este plano e os
documentos de domínio quando necessário.
