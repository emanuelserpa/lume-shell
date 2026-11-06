# UML do Quickshell

O código PlantUML é dividido por responsabilidade para que cada vista continue
legível e útil numa revisão de arquitetura:

- [`shell-uml.puml`](shell-uml.puml): camadas e limites gerais do shell.
- [`shell-uml-runtime.puml`](shell-uml-runtime.puml): instâncias globais e por
  tela criadas por `ShellRoot`.
- [`shell-uml-bar.puml`](shell-uml-bar.puml): composição QML explícita da barra,
  incluindo a ordem relevante de Tray e Network.
- [`shell-uml-state.puml`](shell-uml-state.puml): consumidores de estado,
  serviços compartilhados e adaptadores.
- [`shell-uml-integrations.puml`](shell-uml-integrations.puml): fronteiras com
  APIs Quickshell/Wayland, serviços do sistema e compositores.

Renderize os diagramas localmente com:

```sh
plantuml -tpng docs/shell-uml.puml docs/shell-uml-runtime.puml \
  docs/shell-uml-bar.puml docs/shell-uml-state.puml \
  docs/shell-uml-integrations.puml
```

## Notação e escopo

- Losango preenchido (`*--`): o proprietário instancia aquele objeto QML.
- Seta tracejada (`..>`): dependência, chamada ou publicação/consumo de estado.
- Multiplicidade `0..*`: uma instância por tela conectada.
- Blocos agrupados nas vistas de contexto resumem domínios; não afirmam que
  exista uma classe base, um container dinâmico ou um singleton.
- Os diagramas descrevem o código montado e os limites arquiteturais; não são
  inventário de todas as classes, subprocessos ou componentes não montados.

Para o mapa de arquivos ativos, consulte [`current-state.md`](current-state.md).
As regras e decisões arquiteturais estão em [`architecture.md`](architecture.md).
