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
- [ ] “Ver progresso no terminal” acompanha a execução; indisponibilidade de
  terminal/log deve ter diagnóstico compreensível.
- [ ] Conferir pacote expandido + execução + mensagem longa; botões acessíveis.
- [ ] Conferir acesso ao resultado quando a contagem chega a zero (pendência
  identificada no plano; não presumir resolvida).

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
- [ ] Ícones/tipografia seguem as escalas spotlight; seleção usa pares de tokens.
- [ ] Texto longo acessível no preview; imagem mantém proporção; roda usa convenção.
- [ ] Informações do Sistema fecha por Escape e não por clique fora.

## Notificações e OSD

- [ ] Toast usa PopupCard e tokens de movimento; distinguir abertura do swipe.
- [ ] Margens atuais do toast: topo 45, direita 12; não sobrepor a barra.
- [ ] Timer normal 5.500 ms, baixa urgência 3.500, crítico sem expiração automática;
  hover pausa timer; notificações vazias filtradas e DND preservado.
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
