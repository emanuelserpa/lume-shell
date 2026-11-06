# Cores do wallpaper — plano para o Theme Studio

Status: implementação com revisão de composição em 22/10/2026; estados recolhido e expandido inspecionados no shell. Matriz de contraste/variantes ainda pendente.
Segue o [guia de design](design-guidelines.md), o
[plano prioritário](design-plan.md) e os contratos de
[temas](theme-management.md). A inspiração é escolher a identidade cromática
pessoal a partir do wallpaper, aproveitando o Chameleon existente.

## Revisão de estilo — 23/10/2026

A interface atual usa abas horizontais Temas/Wallpaper/Aparência, seleção tonal
e preview lateral com o wallpaper ativo. A janela cresce com o conteúdo até o
limite da tela; em larguras menores, o preview lateral é ocultado. A lateral de
navegação da tentativa anterior foi removida após feedback sobre identidade
visual. A descrição de 22/10 abaixo é histórica; as abas substituem o fluxo
recolhido/expandido e o preview lateral substitui a amostra tonal de 40 px.

## Revisão de composição — 22/10/2026

Após feedback do usuário, a edição ocupa a mesma seção da paleta existente.
Uma única fileira de amostras cresce no hover; seleção usa marcador separado
e check sobre superfície neutra. Variantes ficam num controle segmentado, com
Cancelar/Aplicar à direita. A prévia tonal tem 40 px e mostra texto, seleção e
destaque. A miniatura de janela e o segundo botão fictício de aplicar foram
removidos. Estados recolhido e expandido conferidos na sessão ativa, 1920×1080.

## Experiência proposta

**Uma imagem, algumas cores possíveis, um shell com a sua escolha.**

A fileira de amostras do Theme Studio vira o ponto de escolha da cor de origem
quando o usuário entra no modo de cores do wallpaper. Ela mantém o crescimento
no hover e ganha seleção, foco por teclado e uma prévia local do resultado.

Fluxo da primeira versão:

1. Abrir o Theme Studio pelo Spotlight e escolher/aplicar o wallpaper na galeria.
2. Na seção **Cores do wallpaper ativo**, ver **Automático** e até cinco cores
   distintas extraídas da imagem. A escolha atual aparece com marca de seleção.
3. Passar o mouse ou mover o foco amplia a amostra, como hoje. Clicar ou usar
   Enter/Espaço seleciona a cor para prévia; hover não aplica nem grava nada.
4. A prévia mostra uma miniatura de barra e um cartão com texto, botão e seleção.
   Ela permite comparar **Escuro · Claro · OLED** antes de aplicar.
5. **Aplicar cores** ativa a variante Chameleon escolhida e sincroniza os
   adaptadores existentes. **Cancelar** descarta a prévia e mostra o estado ativo.
6. A escolha fica salva para a imagem. Voltar ao mesmo wallpaper restaura a
   cor escolhida. **Automático** permite retornar à escolha do algoritmo.

O toque visual especial é ver a mesma cor desdobrar-se em fundo, seleção,
texto e botão na miniatura. A amostra apresenta a cor da imagem; o botão da
prévia apresenta o tom gerado para a interface. Eles podem ter luminosidades
diferentes para manter legibilidade.

## Composição sugerida

Esboço de conteúdo, não uma especificação de dimensões:

```text
[ galeria de wallpapers existente                           ]

Cores do wallpaper ativo
[ Automático ]  [ ● ] [ ●✓ ] [ ● ] [ ● ] [ ● ]

[ Escuro ] [ Claro ] [ OLED ]
┌──────────────────────────────────────────────────────────┐
│ Miniatura da barra             22/10   11:09              │
│ Cartão de exemplo · texto secundário                     │
│ [ Item selecionado ]                  [ Botão ]          │
└──────────────────────────────────────────────────────────┘
                           [ Cancelar ] [ Aplicar cores ]
```

- Reutilizar a posição da fileira de amostras em `ThemePreviewPane.qml`;
  reservar sua área para evitar saltos ao ampliar uma cor.
- Até cinco cores úteis é um máximo, não uma obrigação: remover tons quase
  iguais e não inventar alternativas só para preencher a linha.
- Hover e foco seguem a expansão atual (1,15), com tokens de movimento. A área
  de clique é maior que a faixa decorativa atual de 14 px; foco e seleção têm
  indicadores distintos, com marca de seleção independente da cor.
- Usar os tokens tipográficos e os componentes existentes. A prévia usa uma
  instância local do mesmo contrato de tema; não altera ThemeState globalmente.
- O catálogo de temas continua disponível. Em tema estático, mostrar **Paleta
  do tema** como hoje e uma ação **Usar cores do wallpaper** para entrar na
  experiência proposta. Aplicar torna explícita a mudança para Chameleon.
- A primeira versão trabalha com o wallpaper ativo. Se o carrossel destacar
  outra imagem ainda não aplicada, mostrar “Aplique este wallpaper para escolher
  suas cores” e evitar atribuir as cores antigas à nova imagem.
- Manter o tamanho externo do Theme Studio quando possível; acomodar o conteúdo
  com rolagem local e ações acessíveis, sem comprimir a galeria ou o catálogo.

## Estados e teclado

| Situação | Comportamento |
| --- | --- |
| Extraindo cores | “Lendo cores do wallpaper…”; aplicação desabilitada |
| Opções prontas | Automático e cores naturais distintas; seleção persistida marcada |
| Prévia diferente da ativa | Aplicar e Cancelar disponíveis; nenhuma gravação global |
| Aplicando | Indicador curto; impedir duplicação e conservar a seleção solicitada |
| Falha de extração | Erro legível com tentar novamente; manter o tema ativo |
| Falha de adaptador | Mostrar qual integração falhou; não anunciar sucesso completo |
| Imagem cinza ou com poucas cores | Exibir os tons reais disponíveis; identificar fallback automático, se usado |
| Wallpaper muda durante uma prévia | Descartar resposta antiga e carregar o contexto novo; nenhuma aplicação à imagem errada |

Tab/Shift+Tab percorrem galeria, cores, variante, ações e catálogo em ordem
visual. Ao abrir o Theme Studio, a zona ativa inicia na galeria e seleciona o
wallpaper atual; o foco Qt continua no campo de busca do Spotlight, que encaminha
as teclas para essa zona. Na linha de cores, setas movem foco e Enter/Espaço
selecionam; Escape
cancela a prévia antes de seguir o fechamento habitual do Spotlight. Ao sair
do modo de temas, descartar prévia não aplicada. As zonas atuais de navegação
`gallery`/`catalog` precisam incorporar `colors`, sem capturar a edição da busca.

## O que já existe e o que precisa ser construído

| Base atual | Extensão necessária |
| --- | --- |
| `ThemePreviewPane.qml`: amostras do tema com hover e escala | Seleção de cores da imagem, foco e prévia local |
| `theme-manager.py`: quantização em 48 cores e ranking de candidatos | Retornar candidatos distintos e aceitar uma cor de origem escolhida |
| Material Tonal Spot vendorizado; variantes dark/light/OLED | Gerar as três variantes a partir da seleção, preservando pares de cores |
| `ThemeState.qml` e `ThemeRequest.js`: fila, debounce e revisão | Incorporar pedidos de cor/variante e rejeitar respostas obsoletas |
| Lock do theme-manager e adaptadores | Aplicação serializada e estado de falha por integração |
| Cache de paleta do Chameleon | Cache por imagem + escolha + versão do algoritmo; preferências separadas |

A extração atual também grava cache e sincroniza terminais em alguns caminhos.
Antes de usá-la para prévias, separar cálculo puro de persistência/aplicação:
**preview não pode escrever arquivos ativos, trocar wallpaper nem sincronizar
adaptadores**. Aproveitar o gerador existente, sem duplicar sua matemática no QML.

## Contrato técnico proposto

- Extrair uma imagem reduzida uma vez; classificar candidatos por presença,
  croma e luminosidade, reutilizando a heurística existente. Deduplicar por
  distância perceptual em OKLab/OKLCH, com limiar documentado após avaliar
  fixtures coloridas, escuras e monocromáticas.
- Manter o modo automático compatível com a escolha atual onde possível.
  Não apresentar as cores semânticas de erro/sucesso como se viessem da imagem.
- Resposta de consulta: envelope `{ok, version, data, error}` com identidade
  da imagem, revisão, candidatos, cor automática, escolha persistida e variantes
  necessárias para a prévia. Computar/cachear fora da thread de UI.
- Propor ações `wallpaper-colors`, `preview-wallpaper-color` e
  `set-wallpaper-color` no helper existente. Nomes finais podem mudar; contratos
  de consulta, prévia e aplicação devem continuar separados.
- Toda aplicação carrega identidade esperada da imagem, modo auto/manual,
  cor e variante. O helper valida cor e imagem ainda ativa sob o mesmo lock;
  pedidos antigos não alteram o novo wallpaper.
- Salvar preferência por identidade do conteúdo da imagem, com caminho/mtime/
  tamanho como atalho de cache e hash calculado em background quando necessário.
  Conteúdo alterado no mesmo caminho recebe novas opções; conteúdo idêntico em
  outro caminho pode reutilizar a escolha. Dados ficam no XDG state do shell.
- Cache inclui identidade, preferência e versão do algoritmo; `get`, `set`,
  `next` e `update-wallpaper` respeitam a preferência, inclusive após reinício.
  A otimização atual baseada apenas em caminho/mtime precisa ser atualizada.
- A cor escolhida é origem do gerador, não substituição direta de todos os
  tokens. Variantes mantêm seus pares foreground/container e erros semânticos.
- Manter a última paleta válida se a geração falhar. Gravar estado atomicamente
  apenas depois de gerar uma paleta válida. Relatar falha parcial de adaptador
  separadamente do sucesso da paleta do shell.

## Etapas de implementação

### 1. Base de cores e persistência

- [x] Separar extração/cálculo dos efeitos de aplicação.
- [x] Extrair candidatos, deduplicar, gerar variantes e guardar escolha por imagem.
- [x] Versionar contratos e cache; integrar auto/manual aos comandos existentes.
- [ ] Cobrir fixtures monocromáticas, imagem ausente/alterada e contraste de pares.

Aceitação: mesma imagem/seleção gera a mesma paleta; prévia sem efeitos externos;
reinício e retorno ao wallpaper preservam a escolha; Automático restaura a regra.

### 2. Seleção no Theme Studio

- [x] Fileira de cores, variante, miniatura local e Aplicar/Cancelar.
- [x] Estados de carregamento/erro e retorno ao modo automático.
- [x] Teclado, foco, acessibilidade e geometria com áreas pequenas.

Aceitação: usuário reconhece cor da imagem, seleção provisória e seleção ativa;
hover só anima; todas as ações funcionam com teclado; texto/ações não ficam cortados.

### 3. Integração e revisão visual

- [x] Enfileirar mudanças rápidas sem sobrescrever escolha mais recente.
- [x] Tratar wallpaper divergente durante prévia/aplicação (respostas antigas são descartadas e a aplicação revalida o wallpaper ativo).
- [x] Sincronizar adaptadores somente ao aplicar, com feedback de falhas parciais.
- [ ] Verificar contraste em dark/light/OLED e fundos claros/escuros reais.
- [ ] Atualizar docs de temas, checklist e andamento do plano ativo.

Aceitação: nenhuma alteração global no hover/preview; nenhuma cor aplicada a
wallpaper diferente do pedido; pares de texto normal com meta de 4,5:1 nas
combinações medidas; shell responsivo durante geração e sincronização.

## Evoluções posteriores

Após a primeira versão: conta-gotas sobre a imagem, favoritos de combinações e
estilos Suave/Vibrante. Eles exigem regras próprias e não entram na entrega
inicial. A primeira versão usa o gerador Tonal Spot já instalado e prioriza uma
escolha simples, previsível e reversível.
