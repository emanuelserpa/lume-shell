# Plano: Hyprland e Wayland genérico

Status: implementação das etapas 2–4 em andamento. A sintaxe QML e a integração
em sessões Mango/labwc/Sway/niri ainda não foram validadas.

Revisão após [pesquisa upstream de dwl, Sway, niri, MangoWC e labwc](wayland-compositor-research.md):
Sway recente, niri, Mango e labwc compartilham os protocolos necessários às
funções básicas. Não criar backends próprios para esses quatro. O dwl original
terá suporte parcial conforme protocolos disponíveis. Compatibilidade nativa
existente só permanece onde houver lacuna comprovada ou necessidade de versão.

## Objetivo e escopo

Oferecer duas opções compreensíveis: integração completa com Hyprland e uma
base Wayland genérica orientada às capacidades da sessão. Compartilhar a mesma
interface, temas e serviços. Sway, niri, Mango e labwc usam a mesma base de
protocolos; extensões de compatibilidade existentes são transitórias ou
restritas a lacunas documentadas.

Executar incrementalmente, preservando `stability-contract.md` e a composição
explícita da barra. Este é o plano específico de integração de compositores;
`design-plan.md` permanece a prioridade das melhorias visuais gerais.

Não incluir nesta migração reescrita de áudio, rede, mídia ou notificações,
novo compositor, daemon genérico próprio ou suporte universal prometido a
qualquer desktop Wayland. Registrar protocolos, versões e APIs Quickshell
efetivamente disponíveis antes de declarar compatibilidade.

## Evidências no código atual

- `services/CompositorBackend.js` identifica a sessão, mas não representa
  capacidades nem saúde das conexões.
- `bar/Workspaces.qml` prefere estado nativo de Hyprland/Mango; o comentário
  sobre prioridade do protocolo diverge da seleção real.
- A disponibilidade do protocolo é inferida por lista não vazia. Lista vazia
  pode ser um resultado legítimo e não deve significar protocolo ausente.
- O fallback labwc presume dez desktops e injeta atalhos com `wtype`.
- `scripts/compositor-dispatch.sh` aceita Hyprland pela presença de `hyprctl`
  depois dos ramos Mango/labwc; isso pode selecionar um binário instalado que
  não pertence à sessão ativa.
- `launcher/SpotlightModes.qml` já distingue metadados Hyprland e toplevels
  genéricos, mas a decisão ainda está junto da interface.
- `docs/compositor-integration.md` contém descrições conflitantes da prioridade
  Mango/protocolo. A documentação deve acompanhar o comportamento de cada etapa.

## Arquitetura proposta

    Barra / Spotlight / OSD / painel de monitores
                         ↓
           API do projeto para estado e ações
                         ↓
          seleção de provedor por capacidade
                 ↙                 ↘
       APIs Wayland/Quickshell    extensão da sessão
                                 Hyprland / compatibilidade

Começar com um serviço pequeno `CompositorState.qml` para identidade, capacidades
e seleção. Extrair estado de workspaces e janelas somente conforme seus
consumidores forem migrados; não construir uma infraestrutura de plugins.

Separar APIs nativas e imports Hyprland dos componentes genéricos. Verificar
se a versão Quickshell instalada permite carregar esses componentes de forma
opcional: indisponibilidade de módulo específico não deve derrubar o modo
genérico. Fixar e documentar a versão mínima realmente necessária.

Chamadas de protocolo permanecem nas APIs Quickshell, encapsuladas pelo serviço.
Comandos de compositor continuam em `scripts/compositor-dispatch.sh`; não
transportar objetos Wayland pelo shell nem espalhar CLIs nos componentes QML.
Bloqueio, logout e atalhos globais pertencem à integração de sessão, com
implementação e configuração explícitas, e não ao núcleo do protocolo Wayland.

## Seleção e capacidades

- Configuração proposta: `auto` por padrão, `wayland` para forçar somente
  provedores genéricos, `hyprland` para solicitar a integração nativa.
- Em `auto`, preservar inicialmente a experiência nativa Hyprland e usar a
  base genérica nos demais compositores. Selecionar por recurso, não um único
  backend para o shell inteiro.
- Identidade de sessão é uma pista; confirmar conexão, API e operações
  disponíveis. Executável instalado não é evidência de sessão ativa.
- Cada capacidade informa provedor, estado (`initializing`, `ready`,
  `unsupported`, `error`) e motivo diagnóstico. Separar suporte de lista vazia.
- Se Quickshell não expuser descoberta suficiente, registrar a limitação e
  investigar um helper mínimo de descoberta; não chamar lista vazia de ausência.
- Uma lista e suas ações usam o mesmo provedor e identificadores. Trocas de
  provedor invalidam seleções antigas e acontecem após reconciliar o estado;
  não repetir automaticamente ações de resultado incerto em outro backend.
- Falha temporária não significa falta de suporte. Reconectar com atraso
  progressivo e limite, limpar estado obsoleto e evitar alternância contínua
  entre provedores. Manter um observador compartilhado por conexão.

| Capacidade | Base genérica proposta | Integração específica |
| --- | --- | --- |
| Superfícies de barra e popups | Exigir protocolos necessários às superfícies Quickshell, incluindo layer shell | Regras de blur e efeitos opcionais |
| Listar/ativar workspaces | API de workspace disponível, verificando operações anunciadas | Hyprland; Mango como compatibilidade |
| Listar/ativar/fechar janelas | API de toplevel disponível, verificando cada ação | Metadados e operações adicionais Hyprland |
| PID, geometria e associação janela/workspace | Campos opcionais, nunca presumidos | Dados nativos quando fornecidos |
| Saída focada para OSD | Capacidade opcional; política explícita se ausente | Hyprland/Mango quando disponíveis |
| Configurar monitores | Etapa posterior: avaliar `wlr-output-management` comum, sem presumir espelhamento | Preservar implementação Hyprland atual |
| Submap | Ausente na base | Extensão Hyprland |
| Blur | Não presumir suporte nem aplicação efetiva | Perfil verificado; base usa fundo legível |

Protocolos `ext-*` e `wlr-*` são extensões e não garantias do Wayland básico.
Descobrir também a API disponível ao cliente: o compositor anunciar um protocolo
não basta se Quickshell não o expuser. Portais, quando utilizados, exigem sua
própria descoberta; não substituem automaticamente controle de compositor.

## Contratos de dados e experiência

- Workspaces: identificador opaco, nome, grupo/saída quando conhecidos,
  seleção, urgência e ocupação quando conhecidas. Não converter nomes em
  números nem confundir desconhecido com falso.
- Preservar tags Mango e seleção múltipla. O modelo não deve impor exatamente
  um workspace ativo; próximas/anterior precisam de ordem válida do provedor.
- Janelas: identificador opaco, título, appId e ações permitidas; PID,
  geometria e workspace opcionais. Identificadores vinculados à conexão.
- Ações retornam sucesso confirmado quando observável, solicitação enviada,
  indisponibilidade ou falha. Pedido de fechar não prova que o app encerrou.
  Encerrar processo é ação distinta e exige PID confiável.
- Ausência permanente de recurso omite seu controle, sem lacunas na barra;
  erro temporário tem feedback contextual. Detalhes técnicos ficam no doctor.
- Sem workspace anunciado, não desenhar desktops fictícios. labwc atual deve
  usar o protocolo; preservar atalhos apenas se houver necessidade explícita de
  versão antiga, com quantidade e configuração reais. Migrar a configuração
  existente sem perpetuar esse fallback como parte obrigatória da arquitetura.
- Preservar inicialmente a política de OSD atual por sessão. Definir e testar
  separadamente a política genérica para ausência de saída focada.
- Não alterar espaçamentos, cores, foco ou animações como efeito colateral.

## Etapas e aceitação

### 1. Inventário e contrato

Mapear consumidores em barra, Spotlight, OSD, gravação, monitores, tema,
instalação e sessão. Registrar protocolos/APIs efetivos e baseline Hyprland.
Reconciliar comentários e documentação e definir capacidades com seus estados.

Aceitação: cada operação tem origem, consumidor e comportamento sem suporte;
limitações de descoberta Quickshell documentadas. Sem mudança visual.

### 2. Seleção segura e diagnóstico — implementação

Implementar serviço de capacidades e política `auto/wayland/hyprland`.
Corrigir seleção por presença de binário. Estender `scripts/doctor.sh` com
provedores, capacidades, falhas e dependências ausentes; não exibir títulos
de janelas nem dados privados no diagnóstico padrão.

Implementado: o dispatcher Hyprland exige identidade da sessão além do
executável; `CompositorState.qml` oferece os modos `auto/wayland/hyprland`,
seleciona providers e protege ações de janela; o doctor lê o modo, valida
configuração e consulta anúncios do compositor por `wayland-info` quando
instalado. Estado sem objetos segue como `unreported`, já que a API QML não
expõe o estado de binding do protocolo.

Aceitação restante: validar o modo em sessões reais. `wayland-info` prova
anúncio no compositor, não que Quickshell ligou o protocolo.

### 3. Workspaces, primeiro consumidor — implementação inicial

Encapsular modelos atuais e ativação na API comum. Migrar `bar/Workspaces.qml`
preservando apresentação, rolagem e associação por saída. Tornar identificadores
opacos e migrar fallback labwc configurado; manter Mango funcionando enquanto
se verifica equivalência real do caminho genérico.

Implementado: nomes não numéricos são preservados, protocolo é preferido no
Mango, a lista fictícia labwc foi removida e o watcher Mango permanece ativo
em `auto` para informar a saída focada; seu snapshot só fornece workspaces
quando não há windowsets genéricos (a entrada especial overview continua no
fallback). Hyprland mantém IDs, ocupação e roda nativos.

Aceitação restante: conferir nomes, lista vazia, múltiplas saídas, tags
múltiplas, desconexão/reconexão e ativação nas sessões reais; não marcada como
validada.

### 4. Janelas e recursos opcionais — implementação parcial

Spotlight usa o provider comum para toplevels e `CompositorState` para ativar e
fechar pedidos com tratamento de handles expirados. OSD usa saída focada de
Hyprland/Mango ou primeira tela no caminho genérico. Submap e projeção continuam
recursos Hyprland e respeitam o modo selecionado. PID, geometria de janela e
configuração genérica de monitores continuam opcionais; Quickshell 0.3.x não
expõe API QML de output configuration, e os modos duplicate/extend não têm
equivalência direta em `wlr-output-management`.

Aceitação restante: sessão ativa deve confirmar handles expirados, OSD em
multi-monitor e comportamento completo Hyprland; código mantém PID apenas no
provider nativo e não cria controles de monitor genéricos sem implementação.

### 5. Compatibilidade, instalação e documentação — parcial

Testar base genérica em labwc, Mango, Sway e niri, conforme sessões disponíveis,
para detectar dependências ocultas de identidade; documentar limitações do dwl
original e distinguir builds com patches. Testar também
modo Wayland forçado no Hyprland. Dependências específicas tornam-se opcionais
quando não necessárias à base; documentar atalhos e inicialização por sessão.

Implementado: README, guia genérico, doctor, manifesto de dependências,
arquitetura e matriz de protocolos atualizados. As versões consultadas ficam
registradas na pesquisa upstream.

Aceitação restante: validar base genérica em cada sessão e atualizar a matriz
com versões efetivamente testadas. Não foi possível marcar suporte visual ou
de runtime sem trocar sessões.

## Validação e entrega

Cada etapa vira alteração pequena e reversível, sem remover o caminho antigo
antes da equivalência necessária. Rodar verificações proporcionais e o
validador do projeto nas etapas de código; não reiniciar a sessão em uso para
investigar documentação. Testes puros cobrem seleção, estados, normalização,
solicitações produzidas pela UI e mapeamento de ações no dispatcher.

Testes em sessão cobrem foco/dispensa dos popups, múltiplos monitores, hotplug,
escala fracionária, suspensão/retorno e recuperação de conexão. Medir processos,
CPU em repouso e tempo de atualização antes/depois; evitar polling adicional,
observadores duplicados e novas dependências obrigatórias sem necessidade.

Configuração genérica de monitores e paridade de funções exclusivas ficam para
trabalhos posteriores. O Lume não deve prometer essas capacidades até haver
provider implementado e evidência em sessões reais.
