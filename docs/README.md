# Documentação do Lume

Comece pela tarefa que você quer realizar. Os guias técnicos e planos são
referências para alterações específicas; não é preciso ler tudo em sequência.

## Instalar e usar

- [Apresentação e requisitos](../README.md)
- [Pacote Arch e comandos do launcher](../packaging/arch/README.md)
- Configurar a sessão: [Wayland genérico](wayland-install.md),
  [Hyprland](hyprland-install.md) ou [labwc](labwc-install.md)
- [Temas e wallpapers](theme-management.md)
- [Diagnosticar falhas](crash-debugging.md) e [configuração do sistema](system-setup.md)

## Desenvolver

- [Mapa do shell](current-state.md): componentes ativos e onde encontrar cada recurso.
- [Arquitetura](architecture.md): responsabilidades e componentes compartilhados.
- [Regras de contribuição](../AGENTS.md) e [contratos estáveis](stability-contract.md).
- [Design](design-guidelines.md), [validação](deploy-and-validation.md) e
  [checklist visual](visual-regression-checklist.md).
- [Diagramas](shell-uml.md), quando precisar visualizar as relações.

## Feature reference

Consulte apenas o domínio afetado:

| Tema | Guias |
| --- | --- |
| Busca e dados locais | [Clipboard](clipboard.md), [downloads](ytdlp-downloads.md) |
| Controles do desktop | [Quick Settings](control-center.md), [notificações](notifications.md), [OSD](osd.md), [gravação](screen-recording.md) |
| Conectividade | [Rede](network.md), [Bluetooth](bluetooth.md), [telefone](phone.md), [impressão](printer.md) |
| Hardware e áudio | [Energia](power-controls.md), [monitor do sistema](system-monitor.md), [EasyEffects](easyeffects.md) |
| Dashboard | [Clima](weather.md), [feriados](calendar-holidays.md) |
| Aparência | [Temas](theme-management.md), [portabilidade](theme-portability.md), [Zen](zen-theme.md) |
| Compositores | [Integração](compositor-integration.md), [projeção](display-projection.md), [pesquisa de protocolos](wayland-compositor-research.md) |

## Planos e acompanhamento

Planos descrevem propostas e pendências; o código e o guia do recurso descrevem
o comportamento atual. Consulte o documento específico da tarefa, sem ler todos
os planos em sequência.

- [Plano visual ativo e ordem das fases](design-plan.md)
- [Backlog técnico único](technical-todo.md)
- [Status e próxima prioridade](status.md)
- [Painel web de status e atualizações](../dashboard/)
- [Spotlight](spotlight-raycast-plan.md)
- [Cores do wallpaper](wallpaper-color-plan.md)
- [Wayland genérico](wayland-backend-plan.md)
- [Roadmap legado](roadmap.md): aponta para as fontes ativas e não mantém outra fila.

## Manter a documentação curta

README apresenta e encaminha; o mapa localiza; arquitetura define fronteiras;
o guia do domínio explica os detalhes. Atualize o documento responsável e use
links nos demais. Evite copiar listas de arquivos, valores de tokens, catálogos
de temas ou relatos de cada ajuste para todas as páginas.
