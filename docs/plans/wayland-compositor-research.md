# Pesquisa de compatibilidade Wayland — 07/11/2026

## Conclusão para o Lume

Não há motivo para criar cinco backends completos. Sway recente, niri, MangoWC
e labwc oferecem protocolos comuns para os principais consumidores do shell.
O caminho genérico deve ser a implementação principal nesses quatro; adapters
nativos ficam restritos a recursos adicionais ou defeitos comprovados de uma
versão. O dwl original tem lacunas reais e deve ter suporte parcial declarado.

Esta é uma análise de documentação e código upstream, não uma validação em
sessões reais. `main`/`master` são referências móveis; suporte deve ser medido
na versão instalada. Compartilhar wlroots não implica expor os mesmos protocolos,
e niri demonstra que a interoperabilidade não depende de usar wlroots.

## Matriz relevante ao shell

| Compositor / referência | Workspaces | Listar e controlar janelas | Implicação |
| --- | --- | --- | --- |
| Sway 1.12 | `ext-workspace-v1` | `wlr-foreign-toplevel-management` | Caminho genérico suficiente para barra de workspaces e ações básicas do Spotlight |
| niri 25.08 ou posterior | `ext-workspace-v1` desde 25.08 | `wlr-foreign-toplevel-management`; código 25.08 trata Activate e Close | Não exigir IPC niri para essas funções |
| MangoWC main, projeto identificado como 0.18.5 | `ext-workspace-v1`, pedidos de ativar/desativar e estado de tags | Inicializa `wlr-foreign-toplevel-management` | Não exigir `mmsg` para o caso comum; verificar comportamento por saída e tags múltiplas |
| labwc atual | `ext-workspace-v1`, com exemplo oficial de ativação | `wlr-foreign-toplevel-management`, integração oficial de painéis | Remover necessidade padrão de desktops presumidos e atalhos injetados |
| dwl upstream main consultado | Não encontrado `ext-workspace`; estado de tags em `printstatus()` | `ext-foreign-toplevel-list`; não encontrado `wlr-foreign-toplevel-management` | Listagem não equivale a foco/fechamento; não prometer workspaces clicáveis sem extensão/patch |

Todos os cinco têm suporte a layer shell nas fontes consultadas, permitindo
compartilhar a base de superfícies do shell. A lista acima distingue protocolos
anunciados de funções avançadas: não promete equivalência integral de modelos,
metadados, permissões nem tratamento de cada pedido.

## Evidência primária

### Sway

As [notas oficiais de 1.12](https://github.com/swaywm/sway/releases/tag/1.12)
registram a introdução de `ext-workspace-v1`. O
[servidor nessa tag](https://github.com/swaywm/sway/blob/1.12/sway/server.c)
inicializa o gerenciador foreign-toplevel. Portanto, extrapolar a necessidade
histórica de sway IPC para versões atuais seria incorreto. Versões anteriores
podem precisar de fallback se o Lume decidir atendê-las.

### niri

As [notas de 25.08](https://github.com/niri-wm/niri/releases/tag/v25.08)
explicam o objetivo interoperável do protocolo de workspaces. O
[código foreign-toplevel dessa versão](https://github.com/niri-wm/niri/blob/v25.08/src/protocols/foreign_toplevel.rs)
trata ativação e fechamento. Geometria e posição nas colunas são exemplos de
dados adicionais do IPC, não requisitos de uma lista básica de janelas.

O [output-management atual](https://github.com/niri-wm/niri/blob/main/src/protocols/output_management.rs)
também implementa pedidos de configuração de saídas. Isso permite estudar um
backend de monitores comum; não assumir que um teste de configuração valida
todos os modos de hardware, nem que posicionar saídas implementa espelhamento.

### MangoWC

O [main.c](https://github.com/mangowm/mango/blob/main/src/main.c) inicializa
layer shell, foreign-toplevel e workspaces. A
[implementação de ext-workspace](https://github.com/mangowm/mango/blob/main/src/ext-protocol/ext-workspace.c)
expõe grupos, nomes e estado, e trata ACTIVATE/DEACTIVATE. O
[meson.build consultado](https://github.com/mangowm/mango/blob/main/meson.build)
identifica o projeto como 0.18.5; isso não é a versão mínima do protocolo.

A [wiki atual de barras](https://github.com/mangowm/mango/wiki/status-bar)
recomenda integrações nativas. Essa recomendação não significa ausência de
protocolos genéricos: o código confirma que existem. Antes de retirar o fallback
atual, conferir seleção múltipla, overview e clique na barra de saída não focada.
Suporte ao protocolo não é prova de equivalência nesses cenários.

### labwc

A [documentação oficial de integração](https://labwc.github.io/integration.html)
mostra `ext/workspaces` com ação de ativar, descreve foreign-toplevel para
painéis e recomenda `wlr-randr`/kanshi para monitores. `wtype` é uma escolha de
compatibilidade do Lume atual, não uma necessidade geral do labwc.

### dwl

O [dwl.c upstream](https://codeberg.org/dwl/dwl/src/branch/main/dwl.c), obtido
diretamente do Codeberg, cria layer shell, output-management e
ext-foreign-toplevel-list. Não inicializa ext-workspace nem o gerenciador
wlr-foreign-toplevel-management no arquivo consultado. `printstatus()` publica
estado de tags; isso não fornece uma API comum bidirecional de troca de tags.

Essa conclusão é sobre o upstream consultado. Builds com patches podem expor
protocolos adicionais; detectar o que anunciam, sem presumir suporte pelo nome
`dwl`. Não escolher um protocolo privado de patch como dependência da base.

## Mudanças recomendadas no plano

1. Manter apenas a base Wayland e a integração Hyprland já existente como
   caminhos principais. Não criar adapters Sway, niri, Mango e labwc por padrão.
2. Usar `ext-workspace-v1` e foreign-toplevel onde disponíveis. Adaptar os
   consumidores aos dados reais, incluindo nomes, grupos e seleção múltipla.
3. Manter compatibilidade Mango/labwc existente apenas durante a migração ou
   por necessidade documentada de versão; não iniciar watchers nativos quando
   nenhum recurso os consome.
4. Aceitar suporte parcial no dwl original. Só planejar extensão de controle
   quando houver requisito concreto e protocolo/build definido.
5. Avaliar `wlr-output-management` compartilhado numa etapa posterior, em vez
   de presumir um backend de monitores para cada compositor. Espelhamento,
   persistência e recuperação após aplicar modos precisam de critérios próprios.
6. Reservar integrações nativas para recursos como PID, relação janela-workspace,
   layouts particulares, submaps e ações de sessão, conforme a necessidade real.

O [changelog Quickshell](https://quickshell.org/changelog/) registra
`WindowManager` genérico com ext-workspace em 0.3.0. Isso reforça aproveitar
a API existente; conferir a API de descoberta/ações instalada antes de adicionar
helpers. A base deve identificar protocolos/capacidades, não multiplicar ramos
por nome de compositor.
