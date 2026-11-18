# Status do projeto

Resumo de orientação, não histórico de atividade. Para detalhes e critérios,
consulte o backlog e o plano indicados abaixo.

- **Próxima prioridade:** concluir a verificação visual de P0-01 no
  [plano visual](design-plan.md); a lógica de calendário/log tem cobertura
  automatizada. Após observar que o resultado salvo mantinha o ícone de updates
  na barra indefinidamente, o comportamento foi ajustado para ocultá-lo quando
  não houver pendências nem atualização em execução; o resultado continua no
  histórico. `0.1.0-23` está instalado; falta observar o autohide após uma
  atualização que deixe zero pendências e validar a interação do popup.
- **Progresso técnico:** P0-02 a P0-04 e P1-01 passaram validação offline.
  P1-02 foi reproduzido em simulação controlada e corrigido com watchdog,
  backoff, fila limitada e aviso no histórico; a suíte offline está em 136/136.
  P1-03 teve falsos sucessos corrigidos, teste de integração de `Process` real e
  lacuna de erro no cartão do clima corrigida; revisão Wayland confirmou aviso e
  tooltip, e o item foi fechado. P1-04 fechou com pausa persistente, revisão dos
  estados Pausar/Retomar e seleção Wayland validada em Labwc headless isolado.
  P1-05 teve build, instalação, IPC em Labwc headless, atualização e remoção
  verificados em Arch descartável; ainda não pode ser fechado ou distribuído
  enquanto a licença pública estiver indefinida.
  P1-06 tem testes de falha isolada e confirmações de runtime: Kitty carregou a
  paleta Chameleon por IPC, Hyprland reporta as cores correspondentes e uma janela
  GTK3 mínima renderizou o fundo esperado em Labwc headless; GTK4/libadwaita,
  reload de apps e Mango continuam por conferir.
  P0-05 (CI do GitHub) está suspenso temporariamente a pedido do usuário; o
  workflow de qualidade foi removido e o build de release não depende mais dele.
  Ao retomar, primeiro investigar as cinco falhas vistas no CI remoto; localmente
  a suíte completa passou com 248 testes.
  As demais pendências estão em [backlog técnico](technical-todo.md); não foram
  marcadas como concluídas sem reprodução ou decisão necessária.
- **Planos de domínio:** [Spotlight](spotlight-raycast-plan.md),
  [Theme Studio](wallpaper-color-plan.md) e [backend Wayland](wayland-backend-plan.md)
  só se aplicam a mudanças nesses recursos. A flexibilidade da barra está
  documentada em [bar-flexibility-plan.md](bar-flexibility-plan.md); o seletor
  Ilhas/Contínua foi implementado preservando o layout de módulos, e os perfis
  responsivos restantes continuam planejados.

Atualize este resumo quando a prioridade recomendada mudar. Registre progresso,
decisões e evidências no documento da tarefa; não transforme este arquivo em
diário nem replique a lista completa do backlog.
