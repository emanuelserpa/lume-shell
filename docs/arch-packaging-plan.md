# Plano de empacotamento Arch Linux

Estado: primeira prova local implementada; validação em Arch limpo, licença e
migração do host ainda pendentes.
Escopo: shell atual, sem dock, Arch Linux x86_64/Wayland/systemd.
Este documento detalha as etapas 2, 3 e 6 do
[plano de reprodutibilidade](reproducibility-plan.md).

## 1. Nome, destinos e propriedade dos arquivos

Nome do produto: **Lume**. Nome do pacote: `lume-shell`. Lume é a shell e seus
componentes; Quickshell continua sendo o runtime que carrega o QML. O pacote
depende de `quickshell` e não o substitui. O repositório e o checkout de
desenvolvimento continuam se chamando `quickshell`.

| Conteúdo | Destino proposto | Responsável |
| --- | --- | --- |
| QML, qmldir, scripts, templates, vendor e assets | `/usr/share/lume-shell/` | pacman, somente leitura para o usuário |
| Launcher | `/usr/bin/lume-shell` | pacman |
| Unidade de sessão | `/usr/lib/systemd/user/lume-shell.service` | pacman; ativação pelo usuário |
| Documentação e exemplos de perfis | `/usr/share/doc/lume-shell/` | pacman |
| Licenças redistribuíveis | `/usr/share/licenses/lume-shell/` | pacman |
| Preferências editáveis | `$XDG_CONFIG_HOME/quickshell/` | usuário |
| Estado persistente | `$XDG_STATE_HOME/quickshell/` | usuário |
| Históricos e imagens persistentes | `$XDG_DATA_HOME/quickshell/` | usuário |
| Previews e arquivos regeneráveis | `$XDG_CACHE_HOME/quickshell/` | usuário |
| Sockets, locks e estado transitório | `$XDG_RUNTIME_DIR/` em namespace do projeto | sessão do usuário |

Usar os padrões XDG quando as variáveis correspondentes estiverem ausentes.
Preservar os caminhos já adotados para históricos, cidades e paletas; migrar
somente os que conflitam com a instalação imutável ou ignoram XDG.
As saídas de adapters de tema permanecem nos diretórios dos aplicativos de
destino, respeitando as preferências de integração do usuário.

## 2. Tornar código e preferências independentes

`Quickshell.shellDir` pode continuar localizando scripts e assets distribuídos
com a shell. Python pode continuar localizando templates/vendor a partir de
`__file__`. Esses caminhos relativos ao código favorecem a relocação.

Auditar separadamente toda leitura e gravação de dados do usuário. Exemplo
confirmado: `bar/Workspaces.qml` procura `workspaces.json` em `shellDir`;
precisa usar o diretório de configuração do usuário na instalação empacotada.

Entregas e estado atual:

1. Inventário estático disponível em `docs/dependency-inventory.md` e
   `data/dependencies.json`; a auditoria funcional final ainda está pendente.
2. Manter defaults dentro do pacote e carregar preferências por cima deles.
   Não copiar a árvore QML inteira para cada conta.
3. Checkout preservado; o pacote tem launcher com `quickshell --path` para a
   árvore instalada e mantém preferências em XDG. Não foi feita troca de IPC
   nem migração automática da sessão.
4. O doctor reconhece unidade `lume-shell.service` ou `quickshell.service`,
   distingue arquivos de usuário opcionais e funciona também com a raiz
   instalada. A verificação funcional continua pendente.

Aceitação: o runtime funciona com a árvore de código sem permissão de escrita,
inclusive com variáveis XDG apontando para diretórios diferentes dos padrões.

## 3. Receita e dependências

`packaging/arch/PKGBUILD` fornece um build local de staging que exclui `.git`,
caches, workspace pessoal e preferência de CPU. O modo de publicação fixa um
commit git identificável; por ser fonte VCS, makepkg usa `SKIP` em vez de
checksum. O commit pinado ainda não contém as alterações locais desta prova.

Usar uma lista explícita de arquivos distribuídos. Excluir `.git`, caches,
`__pycache__`, preferências pessoais, históricos, credenciais e configurações
de hardware. Incluir os arquivos `qmldir`, templates e código vendorizado
necessários ao runtime.

Revisar o manifesto antes de transformá-lo em `depends`/`optdepends`:

- Imports QML incondicionais precisam estar disponíveis mesmo se o recurso
  visual correspondente estiver oculto; isso inclui `Qt5Compat.GraphicalEffects`.
- Dependências opcionais precisam de comportamento de ausência comprovado.
  A classificação atual do doctor não basta para definir a receita final.
- `arch_package` deve conter somente nomes reais de pacotes. A indicação atual
  `project files (qmldir)` para `qs.*` deve virar metadado de recurso local.
- Requisitos de compositor ficam separados do runtime comum; não instalar os
  três compositores para executar a shell em uma única sessão.
- Tratar AUR, Homebrew, Flatpak e integrações pessoais explicitamente;
  `makepkg` não deve instalar helpers AUR ou serviços externos por conta própria.
- Revisar licenças do projeto, fontes, SVGs e vendor antes de distribuir.

Registrar versões usadas na validação. Não converter versões instaladas no
host em mínimos suportados sem evidência, nem fixar isoladamente bibliotecas
do Arch rolling release e provocar atualizações parciais.

Aceitação: build em ambiente Arch limpo, conteúdo do pacote inspecionado e
dependências obrigatórias instaláveis sem repositórios específicos do CachyOS.

## 4. Inicialização e perfis

O launcher deve selecionar explicitamente a raiz instalada, repassar sinais
e argumentos suportados e permitir execução de desenvolvimento documentada.
Confirmar a sintaxe no runtime Quickshell alvo antes de implementar.

A unidade fornecida pelo pacote deve executar o launcher como usuário e ter
ciclo de vida associado à sessão gráfica. Validar importação do ambiente
Wayland/D-Bus e a interação com UWSM, evitando inicialização duplicada.

A unidade atual em `~/.config/systemd/user/quickshell.service` executa
`uwsm app -- quickshell`. Lume terá a unidade distinta
`lume-shell.service`; a migração deve detectar a unidade e os drop-ins antigos,
salvar backup, desativar a instância anterior e só então habilitar a nova.
Nunca deixar as duas unidades iniciarem uma shell na mesma sessão.

Perfis Hyprland e labwc devem oferecer exemplos mínimos de atalhos,
portais, bloqueio e idle, sem substituir configurações existentes. Mango
permanece uma integração existente, sem garantia de instalação reproduzível
até receber validação equivalente.

Os serviços do manifesto precisam indicar escopo de sistema/usuário e forma
de ativação. Diagnosticar D-Bus, PipeWire, NetworkManager, BlueZ, UPower e
Polkit conforme a capacidade; não habilitar indiscriminadamente todas as
unidades. Manter o shell sem privilégios e um único servidor de notificações.

## 5. Migração, atualização e retorno

1. Fazer backup versionado das preferências e da unidade/drop-ins atuais,
   registrando origem e destino de cada mudança. Manter o checkout intacto.
2. Instalar o pacote sem trocar automaticamente a sessão em execução.
3. Preparar preferências ausentes a partir dos defaults; preservar valores
   existentes e registrar versão do formato dos dados.
4. Na troca controlada, parar a instância antiga e iniciar a empacotada,
   verificando IPC, barra, notificações e helpers. Não lançar duas shells na
   mesma sessão para compará-las.
5. Documentar retorno à unidade/checkout anterior e restauração de dados
   migrados. Rollback do pacote sozinho não desfaz migração de preferências.

Atualizações via pacman substituem somente arquivos pertencentes ao pacote.
Desinstalação preserva dados do usuário; limpeza desses dados é uma ação
separada. Helpers privilegiados ThinkPad e o projeto `hyprlock-fingerprint`
continuam integrações separadas, sem instalação automática pelo pacote base.

## 6. Ordem das entregas e validação

| Entrega | Critério para avançar |
| --- | --- |
| A — Auditoria final do manifesto e caminhos | Dependências locais/externas e gravações identificadas; lacunas explícitas |
| B — Relocação mínima e launcher | Código somente leitura funciona; preferências XDG e checkout continuam utilizáveis |
| C — PKGBUILD de prova | Build limpo, conteúdo e licenças revisados, instalação/removal exercitados |
| D — Sessão Arch limpa | Novo usuário inicia sem yadm, sem arquivos do autor e sem processos duplicados |
| E — Migração do host | Backup, troca, persistência e retorno verificados |
| F — Publicação | Workflow de release por tag criado; ainda depende de licença definida e validação em Arch limpo |

A relocação mínima de B e a receita C estão implementadas como prova, mas o
pacote ainda não foi instalado. A licença do projeto precisa ser declarada
antes de publicação; não há build limpo do Arch nem teste do pacote instalado.
Hyprland e labwc
recebem validações separadas. Testar ausência de opcionais, escalas/fontes,
temas, mídia, áudio, rede, workspaces, notificações, bloqueio e reinício de
sessão. VM não comprova suspensão, digital ou bateria do hardware real.

Planejar verificações de caminhos temporários, pacote imutável, isolamento de
dados e compatibilidade de preferências. Usar os testes existentes e adicionar
regressões para mudanças de lógica; não iniciar outra shell na sessão diária
para validar instalação limpa.

Nenhuma dessas entregas foi concluída apenas pela criação deste documento.
