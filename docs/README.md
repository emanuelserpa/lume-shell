# Documentação do Lume

Comece pela tarefa que você quer realizar. Os guias técnicos e planos são
referências para alterações específicas; não é preciso ler tudo em sequência.

## Estrutura da pasta

- `docs/` — contratos centrais, arquitetura, mapa de código, status e validação
- `docs/setup/` — instalação do ambiente, compositores, greeter e depuração
- `docs/guides/` — guias técnicos por domínio e recurso
- `docs/plans/` — planos ativos, auditorias e pesquisas de protocolo
- `docs/history/` — registros datados e auditorias concluídas

## Instalar e usar

- [Apresentação e requisitos](../README.md) e [histórico de versões](../CHANGELOG.md)
- [Pacote Arch e comandos do launcher](../packaging/arch/README.md)
- Configurar a sessão: [Wayland genérico](setup/wayland-install.md),
  [Hyprland](setup/hyprland-install.md), [labwc](setup/labwc-install.md) ou
  [ReGreet](setup/greetd-regreet.md)
- [Temas e wallpapers](guides/theme-management.md) e
  [configuração do sistema](setup/system-setup.md)
- [Diagnosticar falhas e crashes](setup/crash-debugging.md)

## Desenvolver

- [Mapa do shell](current-state.md): componentes ativos e onde encontrar cada recurso.
- [Arquitetura](architecture.md): visão simples das camadas, diagrama Mermaid e fronteiras.
- [Regras de contribuição](../AGENTS.md) ([atalho Claude](../CLAUDE.md)) e
  [contratos estáveis](stability-contract.md).
- [Guia visual](design-guidelines.md), [build e validação](deploy-and-validation.md) e
  [checklist visual](visual-regression-checklist.md).
- Referências auxiliares: [ícones Tabler](../assets/tabler/README.md) e
  [referências visuais](../references/README.md).

## Referência por recurso (`guides/`)

Consulte apenas o domínio afetado:

| Tema | Guias |
| --- | --- |
| Busca e arquivos locais | [Spotlight](guides/spotlight.md), [Clipboard](guides/clipboard.md), [downloads (`yt-dlp`)](guides/ytdlp-downloads.md) |
| Controles do desktop | [Quick Settings](guides/control-center.md), [notificações](guides/notifications.md), [OSD](guides/osd.md), [gravação de tela](guides/screen-recording.md), [lockscreen](guides/lockscreen-prototype.md) |
| Conectividade | [Rede](guides/network.md), [Bluetooth](guides/bluetooth.md), [telefone](guides/phone.md), [impressão](guides/printer.md) |
| Hardware e áudio | [Energia](guides/power-controls.md), [monitor do sistema](guides/system-monitor.md), [EasyEffects](guides/easyeffects.md) |
| Dashboard | [Clima](guides/weather.md), [feriados](guides/calendar-holidays.md) |
| Aparência | [Temas](guides/theme-management.md), [portabilidade](guides/theme-portability.md), [Zen Browser](guides/zen-theme.md) |
| Compositores | [Integração](setup/compositor-integration.md), [projeção](guides/display-projection.md), [pesquisa Wayland](plans/wayland-compositor-research.md) |

## Planos e acompanhamento (`plans/`)

Planos descrevem propostas e pendências; o código e o guia do recurso descrevem
o comportamento atual. Consulte o documento específico da tarefa, sem ler todos
os planos em sequência.

- [Status e próxima prioridade](status.md) e
  [painel HTML estático](../dashboard/index.html)
- [Plano visual ativo e ordem das fases](plans/design-plan.md)
- [Auditoria de segurança, memória e desempenho](plans/security-performance-audit.md)
- [Plano de flexibilidade da barra](plans/bar-flexibility-plan.md)
- [Plano do Spotlight](plans/spotlight-raycast-plan.md)
- [Cores do wallpaper](plans/wallpaper-color-plan.md)
- [Backend Wayland genérico](plans/wayland-backend-plan.md)
- [Histórico do plano visual](history/design-plan-log.md) e
  [roadmap legado](plans/roadmap.md)

## Manter a documentação curta

`README.md` apresenta e encaminha; `current-state.md` localiza; `architecture.md`
define fronteiras; o guia em `docs/guides/` ou `docs/setup/` explica os detalhes.
Atualize o documento responsável e use links nos demais, evitando duplicar
listas de arquivos, valores de tokens ou relatos em várias páginas.
