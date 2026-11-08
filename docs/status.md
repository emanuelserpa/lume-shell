# Status do projeto

Resumo de orientação, não histórico de atividade. Para detalhes e critérios,
consulte o backlog e o plano indicados abaixo.

- **Próxima prioridade:** concluir a verificação visual de P0-01 no
  [plano visual](design-plan.md); a lógica de calendário/log tem cobertura
  automatizada e o popup foi conferido em harness integrado nos estados de
  execução/erro; falta validar interação e retomada na instância instalada.
- **Progresso técnico:** P0-02 a P0-04 e P1-01 passaram validação offline.
  P1-02 foi reproduzido em simulação controlada e corrigido com watchdog,
  backoff, fila limitada e aviso no histórico; a suíte offline está em 130/130.
  P1-03 teve falsos sucessos corrigidos, teste de integração de `Process` real e
  lacuna de erro no cartão do clima corrigida; revisão Wayland confirmou aviso e
  tooltip, e o item foi fechado. P1-04 fechou com pausa persistente, revisão dos
  estados Pausar/Retomar e seleção Wayland validada em Labwc headless isolado.
  P1-06 ganhou testes de recuperação em diretórios temporários; na sessão ativa,
  o gerenciador reportou Chameleon e 11 adaptadores em sync, mas aparência dos
  aplicativos e recuperação real continuam por conferir.
  P0-05 (CI do GitHub) está suspenso temporariamente a pedido do usuário; o
  workflow de qualidade foi removido e o build de release não depende mais dele.
  Ao retomar, primeiro investigar as cinco falhas vistas no CI remoto; localmente
  a suíte completa passou com 248 testes.
  As demais pendências estão em [backlog técnico](technical-todo.md); não foram
  marcadas como concluídas sem reprodução ou decisão necessária.
- **Planos de domínio:** [Spotlight](spotlight-raycast-plan.md),
  [Theme Studio](wallpaper-color-plan.md) e [backend Wayland](wayland-backend-plan.md)
  só se aplicam a mudanças nesses recursos.

Atualize este resumo quando a prioridade recomendada mudar. Registre progresso,
decisões e evidências no documento da tarefa; não transforme este arquivo em
diário nem replique a lista completa do backlog.
