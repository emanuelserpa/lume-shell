# Portabilidade de temas — Hyprland Atomic

Este documento registra uma análise exploratória separada. O trabalho atual
de reprodutibilidade está limitado a Arch Linux; nenhuma tarefa para Fedora,
Silverblue, Ublue ou Hyprland Atomic faz parte do escopo ativo.

Este guia propõe melhorias para instalar o shell em uma conta nova no
Fedora Silverblue/Ublue com Hyprland, sem copiar configurações pessoais da
máquina original. É um plano de implementação e validação: as etapas abaixo
não representam funcionalidades já disponíveis.

O contrato atual dos adaptadores está em [theme-management.md](theme-management.md).
As configurações externas ao shell estão em [system-setup.md](system-setup.md).

## Diagnóstico do projeto de destino

Na revisão de 5 de outubro de 2026 do
[hyprland-atomic](https://github.com/emanuelserpa/hyprland-atomic/tree/dd5609f309cf5c670c28112fa114e45ed112b041)
(commit `dd5609f`), foram
identificadas estas condições:

| Área | Configuração encontrada | Consequência a investigar ou corrigir |
| --- | --- | --- |
| Pacotes Qt | `recipes/recipe.yml` instala `qt6ct` e `kvantum`, mas as dotfiles não incluem suas configurações | Instalar os executáveis não prepara os arquivos esperados pelo adaptador |
| Ambiente Qt | `.config/uwsm/env` define `QT_QPA_PLATFORMTHEME=qt6ct`; `.config/zsh/.zshenv` define `qt5ct` | Aplicativos lançados por caminhos diferentes podem receber ambientes diferentes |
| Estilo Qt | UWSM força `QT_STYLE_OVERRIDE=kvantum`; o gerenciador de temas escreve `style=breeze` no qt6ct | A configuração de sessão e o adaptador têm decisões conflitantes |
| Primeiro login | `hyprland-atomic-user-setup` copia arquivos ausentes e grava um marcador de versão | Não verifica nem inicializa a integração de temas |
| GTK | O adaptador pode usar um tema instalado como base e aceita sucesso parcial de escrita | O resultado depende do ambiente; escrever CSS não prova que o aplicativo o carregou |

Essas evidências mostram lacunas de instalação, especialmente em Qt. Não
comprovam a causa da falha GTK na máquina de destino: ainda é necessário
identificar os aplicativos afetados, se são nativos ou Flatpak e o ambiente
real dos processos. Não tratar isso como defeito do Silverblue por hipótese.

## 1. Unificar o ambiente da sessão

No repositório `hyprland-atomic`:

1. Centralizar a política Qt no ambiente UWSM; remover a redefinição
   contraditória no Zsh.
2. Escolher e testar um caminho principal para aplicativos Qt 6. Para seguir
   o adaptador atual, preparar qt6ct com Breeze, verificar a disponibilidade
   do plugin de estilo na imagem e retirar o override que força Kvantum.
3. Se Kvantum for a escolha desejada, adaptar o gerenciador para respeitar
   essa escolha e distribuir uma base compatível, com licença e versão
   documentadas. Não selecionar uma base arbitrária encontrada no usuário.
4. Tratar aplicativos Qt 5 separadamente nos testes; não presumir que uma
   variável apontando para qt6ct resolva as duas gerações.
5. Encerrar e iniciar a sessão após mudanças de ambiente. Reiniciar apenas
   o Quickshell não atualiza o ambiente de aplicativos já abertos.

Não impor `GTK_THEME` globalmente como solução de integração. Conferir e
remover valores antigos somente quando identificados como conflitantes.

## 2. Preparar uma conta nova sem sobrescrever preferências

Dividir as responsabilidades:

- **Imagem Atomic:** pacotes, plugins de estilo, configuração padrão de
  sessão e assets licenciados necessários.
- **Setup do usuário:** criar somente configurações ausentes e executar
  migrações explícitas, com backup quando houver alteração de arquivo existente.
- **Quickshell:** gerar paletas, aplicar adaptadores disponíveis e relatar
  limitações por adaptador.

O setup deve ser idempotente: uma segunda execução não duplica seções nem
descarta alterações do usuário. Respeitar `XDG_CONFIG_HOME`, `XDG_DATA_HOME`,
`XDG_STATE_HOME` e `XDG_CACHE_HOME`, incluindo caminhos com espaços.

Para Qt, criar uma configuração mínima válida do qt6ct quando ausente e
quando essa for a política da imagem. Inserir as chaves na seção correta
do INI, preservando as demais seções. Verificar seleção da paleta customizada
e do estilo, além da existência do arquivo de cores.

Não depender de `~/.config/Kvantum` previamente preenchido. Corrigir os
caminhos do adaptador que ainda ignoram `XDG_CONFIG_HOME`. Se houver suporte
a Kvantum, excluir temas gerados da descoberta de templates para evitar
recolorir repetidamente o próprio resultado.

O marcador de versão do setup deve permitir novas migrações: uma conta que
já completou o primeiro login também precisa receber a correção. Gravar
sucesso somente depois de concluir a preparação obrigatória.

## 3. Tornar o GTK previsível

O shell já inclui `scripts/templates/gtk-chameleon.css`. Validar esse
fallback sem nenhum tema pessoal instalado, tanto em tema claro quanto
escuro, antes de depender dele numa imagem nova.

- Tornar a seleção de templates determinística. Usar o fallback do projeto
  ou uma base explicitamente suportada, evitando o primeiro tema disponível.
- Testar separadamente GTK 3, GTK 4 e aplicativos libadwaita.
- Distinguir geração do tema, escrita de `settings.ini`, escrita de CSS e
  atualização de `gsettings`. Hoje um sucesso parcial pode mascarar falhas.
- Tratar schemas/chaves opcionais indisponíveis como capacidade ausente,
  sem afirmar que toda a integração funcionou ou falhou.
- Preservar backup de CSS preexistente e documentar como restaurá-lo.

A aparência de aplicativos já abertos também precisa de teste. Registrar
quais exigem reabertura; não prometer atualização imediata para todos.

## 4. Validar Flatpak como um destino separado

Para o Zen distribuído pela imagem, consultar também
[Tema do Zen Browser](zen-theme.md): investigação do editor nativo e
remoção do adaptador experimental. O shell não gerencia os temas do Zen.

Usar as permissões descritas em [system-setup.md](system-setup.md#flatpak-theming)
como referência e verificar os overrides efetivos na máquina de destino.
Preferir configurar primeiro um aplicativo de teste, antes de aplicar uma
política a todos os Flatpaks do usuário.

Confirmar acesso aos arquivos de tema e CSS, disponibilidade dos recursos
necessários no runtime e preferência de aparência recebida pela sessão.
Não considerar a integração Flatpak validada apenas porque o equivalente
nativo mudou de cor. Não adicionar overrides globais silenciosamente a cada
troca de tema.

## 5. Melhorar o diagnóstico do gerenciador

Adicionar futuramente uma operação de diagnóstico sem alterações no sistema.
Ela deve informar, por adaptador:

- disponibilidade do backend e arquivos necessários;
- caminhos efetivamente usados;
- configuração gerada, seleção ativa e ambiente esperado;
- falha, dependência ausente ou verificação ainda pendente;
- ação concreta para resolver a condição.

Preservar a compatibilidade dos booleanos atuais de `adapters`, adicionando
detalhes em um campo separado do JSON versionado. Não confundir “arquivo
gerado”, “configuração selecionada” e “aparência confirmada”: esta última
exige validação do aplicativo.

Esse diagnóstico ainda não existe. Para coletar evidências hoje, usar na
sessão de destino:

```bash
printenv QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE GTK_THEME XDG_CURRENT_DESKTOP
systemctl --user show-environment | grep -E '^(QT_QPA_PLATFORMTHEME|QT_STYLE_OVERRIDE|GTK_THEME|XDG_CURRENT_DESKTOP)='
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface color-scheme
flatpak override --user --show
journalctl --user -u quickshell.service -b --no-pager -n 100
```

Comandos de ferramentas ausentes podem falhar; registrar isso como evidência.
O ambiente do terminal e do gerenciador systemd deve ser comparado com o do
aplicativo afetado. O comando atual `theme-manager.py get` não deve ser
apresentado como diagnóstico estritamente somente leitura: a descoberta de
paletas pode atualizar caches e adaptadores.

## 6. Testar antes de distribuir

Adicionar testes isolados, com HOME/XDG temporários e subprocessos simulados:

| Cenário | Resultado esperado |
| --- | --- |
| Conta sem configurações de Qt | Setup prepara o caminho escolhido; adaptador não depende da máquina original |
| Configuração existente | Preferências preservadas, migrações documentadas e reversíveis |
| XDG personalizado | Leitura e escrita usam o mesmo diretório configurado |
| GTK sem templates externos | Fallback incluído gera os arquivos necessários |
| Backend ou schema ausente | Diagnóstico identifica a limitação sem sucesso enganoso |
| Falha de escrita ou de comando | Erro contextual e nenhum falso estado de sincronização completa |
| Trocas rápidas | Última seleção chega aos adaptadores sem aplicações concorrentes |
| Segunda execução do setup | Sem duplicação ou perda de configuração |

Rodar `./scripts/validate.sh` no Quickshell. No projeto Atomic, examinar e
executar os validadores próprios conforme seu escopo. Testes do shell não
substituem a validação da imagem.

Validar numa VM ou conta limpa da imagem de destino, sem importar o HOME da
máquina original:

1. Iniciar a sessão Hyprland/UWSM e verificar os logs do shell.
2. Aplicar um tema estático claro e um escuro; testar Chameleon com wallpaper.
3. Conferir um aplicativo de cada grupo: GTK 3, GTK 4/libadwaita, Qt 6,
   Qt 5 se suportado, e Flatpak.
4. Comparar abertura pelo launcher e pelo terminal.
5. Alternar rapidamente e conferir a última escolha após a aplicação terminar.
6. Reabrir aplicativos e fazer logout/login para verificar persistência.
7. Repetir com conta já configurada para validar a migração e o backup.

Critério de conclusão: instalação nova reproduz a integração declarada,
limitações aparecem no diagnóstico e contas existentes mantêm suas
preferências. Registrar imagem/commit testado e aplicativos usados.

## Ordem sugerida de implementação

1. Corrigir o conflito UWSM/Zsh e decidir o estilo Qt suportado na imagem.
2. Preparar qt6ct no setup e corrigir caminhos XDG no adaptador.
3. Acrescentar diagnóstico por etapa e testes de instalação limpa.
4. Tornar templates GTK/Qt determinísticos e validar Flatpak.
5. Validar a imagem numa conta nova e numa conta migrada; publicar as
   instruções com as limitações observadas.

Manter essas mudanças separadas da composição da barra e dos popups estáveis.
