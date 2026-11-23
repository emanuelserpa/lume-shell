# Plano de flexibilidade da barra

## Entrega atual

O seletor visual `Ilhas` / `Contínua` está implementado no estúdio de aparência
do Spotlight. `Ilhas` continua como padrão; `Contínua` desenha uma superfície
única sob a composição atual. A escolha fica em
`$XDG_CONFIG_HOME/quickshell/bar.json`, com versão e fallback seguro. A ordem,
visibilidade e configuração dos módulos não são alteradas por esse seletor.
As demais etapas abaixo continuam sendo planejamento.

## Objetivo

Permitir que cada pessoa ajuste a composição e a densidade da barra sem perder
a hierarquia das ilhas, o comportamento por monitor nem os contratos já
estáveis. A barra continuará compacta e adaptada ao tema. A flexibilidade será
feita por opções e perfis compreensíveis, não por uma tela de edição livre que
permita combinações difíceis de manter.

As próximas etapas descrevem trabalho futuro. A composição de referência está
em [`current-state.md`](../current-state.md), e a implementação explícita em
`bar/Bar.qml` permanece protegida pelo
[contrato de estabilidade](../stability-contract.md).

## Decisão sobre atualizações na ilha central

É tecnicamente viável colocar ali o acesso às atualizações, e isso não é uma
ideia absurda. A central já é uma região distinta, mas hoje tem uma função clara:
clima e relógio, enquanto a ilha de mídia usa o espaço à direita dela. Colocar
mais uma pill permanente no centro aumentaria a largura central e faria a mídia
sumir com mais frequência em telas estreitas.

Recomendação: manter o `UpdateControl` completo à direita como padrão e permitir
uma opção **Atualizações no centro**. Nessa posição, mostrar um indicador
compacto somente durante uma atualização, quando há atualizações disponíveis
ou quando o último resultado foi uma falha. Sem esses estados, o indicador não
ocupa espaço. O clique abre o mesmo `SystemUpdatePopup`, com o mesmo progresso,
resultado e acesso ao log. O sucesso antigo não deve deixar um ícone permanente
no centro.

O popup deve ter um único dono, mesmo que a âncora visual mude entre centro e
direita. O planejamento técnico dessa movimentação precisa evitar dois popups
independentes ligados a `UpdateState`. A posição central é opcional e deve
respeitar a área de segurança do relógio/clima; quando a largura ficar curta,
prevalece o conteúdo principal e o indicador central pode ser omitido, sem
perder acesso às atualizações pelo perfil padrão ou pela seção de configurações.

Essa composição segue um padrão já usado pelo Omarchy: o relógio ocupa uma
caixa central que permanece centrada, enquanto indicadores, clima e update
badge ficam em slots vizinhos (`centerBegin` e `centerEnd`). O badge de update
só aparece quando há atualização disponível, sem empurrar o relógio para fora
do centro. Para o Lume, o equivalente seria adicionar slots laterais ao cluster
central, mantendo o `Clock` no eixo da tela e a ilha de mídia depois do limite
da região central.

## Princípios e limites

- A configuração padrão reproduz exatamente a barra atual.
- O modo atual e padrão continua sendo `Ilhas`.
- A futura `Barra contínua` é apenas uma composição visual: une os fundos das
  mesmas regiões sem modificar a disposição, ordem ou preferências dos módulos.
- Preferências controlam opções de produto; cor, transparência, borda e tipografia
  continuam vindo de `Theme.qml` e do tema ativo.
- Não permitir que configurações escondam permanentemente informação crítica:
  estados de gravação, alertas e falhas importantes precisam continuar acessíveis
  em outro local documentado.
- Não introduzir ordenação de módulos com `Loader` ou `Repeater`. `Bar.qml`
  mantém componentes explícitos; `Network` continua depois de `Tray`.
- Não duplicar serviços, timers, popups ou processos por monitor. Os dados de
  estado continuam compartilhados; cada barra só projeta o que pertence à tela.
- Restrições de largura devem ser previsíveis: esconder componentes opcionais
  segundo prioridade definida, sem comprimir pills até truncar ícones ou ações.
- A barra mantém a mesma altura e zona exclusiva enquanto o usuário alterna
  opções; uma futura mudança vertical precisa ser outra decisão de design.

## Referência: Omarchy Quattro

Na versão Quattro atual, o Omarchy usa um único shell Quickshell e guarda a
configuração da barra em `~/.config/omarchy/shell.json`. O layout tem cinco
seções lineares — `left`, `centerBegin`, `center`, `centerEnd` e `right` — mais
uma seção `tray` dentro do drawer. `center` é uma caixa centrada; os slots
`centerBegin` e `centerEnd` crescem para fora dela, mantendo o relógio central
mesmo quando clima e atualizações aparecem ou desaparecem. O padrão do Omarchy
coloca indicadores e o update badge próximos ao relógio; o badge só fica visível
quando há atualização disponível. [Manual da barra](https://github.com/omacom/omarchy/blob/quattro/manual/05-the-top-bar.md),
[schema e seções](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md).

O usuário pode arrastar widgets entre seções, reordená-los, colocar alguns no
drawer da bandeja e mover a barra para outra borda. Há comandos `omarchy bar`
para mover/configurar widgets e comandos de plugin para habilitá-los ou
desabilitá-los. Widgets customizados podem ser comandos simples ou itens QML; os
metadados declaram opções e seção inicial. A configuração editada torna-se
canônica e não recebe merge profundo de novos defaults; `omarchy bar defaults`
restaura o layout distribuído. [Guia de personalização e widgets](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/bar/README.md),
[manual e comandos](https://github.com/omacom/omarchy/blob/quattro/manual/05-the-top-bar.md).

Para o Lume, a lição direta é separar o centro em âncora fixa e vizinhanças; isso
resolve o caso de atualizações sem sobrecarregar o relógio. A personalização
completa do Omarchy vai além dos toggles e perfis deste plano: inclui reorder
ao vivo, widgets/plugins externos e migração/versionamento da configuração.
Esses recursos não entram na primeira entrega. Uma etapa posterior precisa
decidir explicitamente se o contrato de composição QML explícita será revisto;
até lá, o plano não promete drag-and-drop nem extensibilidade de plugins.

## Opções para a primeira versão

1. **Superfície:** manter `Ilhas` como padrão e oferecer `Barra contínua` como
   alternativa visual. Trocar esse modo não edita a configuração de módulos nem
   altera posições, ordem ou popups.
2. **Visibilidade de módulos opcionais:** clima, mídia, monitor do sistema,
   impressora, Bluetooth e indicadores de estado. O acesso a workspaces,
   relógio, notificações/Quick Settings, áudio e energia precisa manter um
   caminho acessível, ainda que a pessoa escolha outra localização.
3. **Posição de atualizações:** direita (padrão) ou indicador compacto no centro,
   com as regras de visibilidade acima. Para outros módulos, avaliar posições
   somente entre slots predefinidos; a primeira versão não promete mover todo
   componente livremente entre regiões.
4. **Densidade:** atual/compacta e confortável, alterando apenas espaçamentos e
   padding por tokens. Não criar uma escala independente de cores ou fontes.
5. **Aplicação por tela:** primeiro aplicar as mesmas preferências em todos os
   monitores. Overrides por monitor ficam fora da primeira versão, até a
   persistência global e os casos de escala diferente estarem estáveis.

Por enquanto, o shell continua iniciando no modo `Ilhas`. O modo contínuo será
uma preferência visual separada, sem migração nem alteração do layout salvo.

Cada perfil deve ser uma combinação validada. Se uma combinação não couber,
usar a prioridade de conteúdo abaixo em vez de inventar uma geometria local.

## Prioridade quando falta espaço

1. Preservar as regiões de navegação e controles essenciais.
2. Ocultar primeiro a ilha de mídia, que já é condicional hoje.
3. Omitir o indicador opcional de atualização no centro; as atualizações seguem
   acessíveis pela posição padrão ou configurações.
4. Reduzir espaços até o limite compacto configurado.
5. Ocultar módulos opcionais segundo a preferência e uma ordem documentada.

Nunca sobrepor centro e direita, deixar uma popup sem âncora visível ou reduzir
o alvo de clique abaixo do mínimo do tema. Em monitores estreitos, a configuração
precisa explicar o que foi temporariamente ocultado e preservar o acesso ao
controle.

## Persistência e interface de configuração

Expandir o arquivo versionado já usado pelo modo visual em
`$XDG_CONFIG_HOME/quickshell/`, separado de `Theme.qml` e dos dados de estado.
Novas preferências precisam ter defaults, validação e fallback seguro para
valores inválidos; gravações devem ser atômicas e opções desconhecidas devem ser
ignoradas. As mesmas preferências são consumidas pelas instâncias da barra em
todas as telas.

A configuração deve aparecer em uma seção **Barra** das configurações do Lume,
com controles de modo visual, visibilidade, densidade e posição das atualizações.
Mostrar uma prévia simples da composição antes de oferecer edição avançada. Deve
haver uma ação para restaurar o padrão e uma indicação clara quando um módulo
foi omitido por falta de espaço. Não construir primeiro um editor livre de
arrastar e soltar.

## Etapas de implementação

### Etapa 0 — Fechar o escopo visual

- Desenhar os modos `Ilhas` e `Barra contínua` com a mesma composição, em uma
  tela estreita, usando o tema ativo e uma variante clara.
- Medir o espaço real com Tray cheia, texto de clima longo, gravação ativa,
  status de rede e muitos updates.
- Confirmar a lista de módulos opcionais e a prioridade de ocultação.
- Confirmar o fundo contínuo e as superfícies de ilhas em Hyprland, Mango e
  labwc, sem criar cores independentes do tema.

**Saída:** matriz de perfis e exemplos de largura; nenhuma mudança de runtime.

### Etapa 1 — Preferências e comportamento responsivo

- Introduzir um modelo pequeno, versionado e testável de preferências.
- Manter `Ilhas` como default; separar o modo visual das preferências de módulos.
- Adicionar apenas toggles de visibilidade e densidade que não reordenem a
  composição.
- Implementar prioridades de largura e publicar quais itens foram omitidos.
- Garantir que todas as barras por monitor usem a mesma configuração sem
  consultar novamente os backends.

**Aceite:** configuração inválida retorna ao default, reinício mantém escolhas,
e nenhum controle essencial fica inacessível nas larguras suportadas.

### Etapa 2 — Slots e posição das atualizações

- Separar visualmente o indicador de atualizações da propriedade do popup sem
  duplicar `SystemUpdatePopup` ou o estado global.
- Adicionar seleção direita/centro; no centro, usar o indicador compacto sob
  demanda descrito neste plano.
- Verificar âncora e foco do mesmo popup em ambos os slots, incluindo durante
  execução, sucesso, falha e atualização disponível.

**Aceite:** exatamente um popup proprietário; o centro continua legível e a
mídia cede espaço de forma previsível.

### Etapa 3 — Configurações adicionais

- Adicionar prévia e ação restaurar padrão à seção Barra.
- A opção `Barra contínua` já une os fundos das regiões existentes. Preservar
  essa separação visual nas mudanças de prévia e restaurar padrão.

**Aceite:** alternar a superfície não edita a configuração dos módulos nem
altera ações, foco, ordem, popups, serviços, altura, zona exclusiva ou
comportamento multi-monitor.

### Etapa 3B — Extensibilidade avançada (fora da primeira entrega)

- Decidir se a barra deve permitir ordem livre e módulos de terceiros, além dos
  slots predefinidos e toggles da primeira entrega.
- Se isso for desejado, propor primeiro uma atualização do contrato de
  estabilidade e uma API de widget; avaliar ciclo de vida, permissões, reload,
  atualização de schema e recuperação do layout inválido.
- Oferecer uma ação inequívoca para restaurar defaults e definir como novas
  versões introduzem widgets sem apagar nem congelar silenciosamente a
  configuração existente.

**Aceite:** somente após decisão explícita sobre manutenção e segurança de
plugins executados dentro do processo do shell.

### Etapa 4 — Revisão por monitor e compositor

- Validar tela principal e secundária, áreas 1920×1080 e estreita, escala 100% e
  fracionária disponível.
- Conferir Hyprland e, quando houver sessão disponível, Mango e labwc.
- Testar tema claro/escuro, preferências de vidro, estados longos e as transições
  entre oculto, disponível, execução e resultado de atualização.

**Aceite:** sem colisões/cortes; um monitor não muda o estado do outro; fallback
de compositor não depende de blur; resultado e falha continuam acessíveis.

## Verificação

- Testes puros para defaults, migração de versão, valores desconhecidos,
  combinações inválidas, prioridade de largura e elegibilidade dos módulos.
- Cobertura QML para ler/aplicar/resetar preferências e alternar a superfície sem
  duplicar popup ou instâncias de serviço; verificar que layout permanece igual.
- Checklist visual para largura pequena, barra cheia, segundo monitor, posição
  central das atualizações, falha e sucesso restaurado.
- Rodar `scripts/validate.sh --offline`; instalação/execução real é uma etapa
  posterior, não requisito para aprovar o plano.

O layout de módulos permanece a referência até cada etapa correspondente ser
implementada, validada e registrada no checklist.
