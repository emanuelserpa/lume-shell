# Status do projeto

O Lume é distribuído para Arch Linux pelo pacote `lume-shell`, sob licença MIT.
O código atual está em `main`; tags Git definem as versões públicas. Consulte
o [guia do pacote](../packaging/arch/README.md) para instalação e release.

- **Próxima revisão visual:** concluir P0-01 do [plano visual](design-plan.md):
  testar calendário e popup de atualizações na sessão instalada, inclusive
  retomada da suspensão, interação e resultado após reabrir.
- **Qualidade remota:** continua suspensa por decisão do usuário; validação
  local e build de release são fluxos separados.
- **Distribuição e temas:** ainda falta conferir o pacote em uma sessão Arch
  recém-instalada e validar GTK4/libadwaita e recarga de aplicativos abertos.
- **Desempenho:** a [auditoria](security-performance-audit.md) registra as
  correções de segurança e memória e as medições que ainda faltam. A versão
  instalada localmente não define o estado da release pública.

Planos de [Spotlight](spotlight-raycast-plan.md), [cores do wallpaper](wallpaper-color-plan.md),
[barra](bar-flexibility-plan.md) e [Wayland](wayland-backend-plan.md) só se aplicam
quando a mudança atingir esses recursos. Detalhes de implementação ficam nos
guias de domínio; este arquivo apenas aponta o próximo trabalho.
