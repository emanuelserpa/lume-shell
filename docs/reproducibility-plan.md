# Plano de portabilidade e reprodução da shell

Data: 05/11/2026. Estado: em andamento. Escopo: reproduzir a shell atual no
Arch Linux, sem dock. Outras distribuições estão fora do trabalho atual.

## Objetivo e contrato

Instalar uma versão identificável da shell em uma instalação Arch Linux limpa e reproduzir seu
ambiente de execução, recursos suportados e identidade visual sem clonar os
dotfiles pessoais do autor. Preservar geometria, fontes, cores, animações,
notificações, mídia, áudio e comportamento de teclado existentes.

O pacote deve declarar versões e dependências; a integração com o sistema
deve declarar seus requisitos. Não prometer equivalência absoluta entre
drivers, hardware, escalas e compositores diferentes, nem builds idênticos
byte a byte sem comprovação específica.

Este plano rege o trabalho de portabilidade solicitado. O
[plano de design](design-plan.md) continua sendo a prioridade para melhorias
visuais gerais; o [contrato de estabilidade](stability-contract.md) permanece
obrigatório. Portabilidade não autoriza redesenhar componentes estáveis.

## Evidências iniciais e lacunas

- `README.md` e os guias de instalação dependem de Arch/CachyOS, yadm e
  arquivos externos ao repositório da shell.
- `scripts/system-update.sh`, `arch-updates.sh`, `aur-updates.sh` e
  `yay-pkexec.sh` contêm integração específica com pacman/yay.
- `scripts/doctor.sh` e `scripts/validate.sh` já existem e devem ser
  estendidos, evitando sistemas paralelos de diagnóstico.
- O inventário estático inicial está em
  [dependency-inventory.md](dependency-inventory.md); ele confirma
  dependências por capacidade e lista lacunas de versão e caminhos pessoais.
- A integração com compositores já possui uma fronteira documentada em
  [compositor-integration.md](compositor-integration.md).
- O perfil Hyprlock agora usa caminhos `$HOME` para wallpaper, cache e helper,
  além de fundo sólido de reserva. ThemeState gera o include de cores no
  primeiro carregamento; o perfil ainda depende dos dotfiles e das fontes do
  host, e continua fora do pacote instalável.
- A receita Arch do pacote `hyprlock-fingerprint` e seu patch estão no projeto
  separado `~/Projetos/hyprlock-fingerprint`; a autenticação após suspensão ainda exige
  validação física. Os modelos opcionais de hook e drop-in do leitor Synaptics
  também foram trazidos ao repositório. A integração permanece específica do
  host e do Arch, sem fazer parte do runtime genérico da shell.
- Os guias incluem ajustes de hardware pessoal e instruções que precisam
  ser reconciliadas com o código atual antes de virarem instalação pública.
- A revisão inicial dos comandos Arch encontrou `nmcli` e `bluetoothctl`
  listados como pacotes, embora sejam executáveis fornecidos por
  `networkmanager` e `bluez-utils`; as listas foram corrigidas. A auditoria
  também acrescentou o backend `awww` e o seletor `zenity`, usados pelo fluxo
  de wallpaper, e moveu `imagemagick` para opcionais. A revisão dos guias segue
  aberta para energia e requisitos específicos de sessão.

Esta inspeção é preliminar; não constitui inventário completo de dependências
nem evidência de execução em uma instalação Arch Linux limpa.

## Alvo atual

Arch Linux x86_64, Wayland e systemd. O host de desenvolvimento atual é
CachyOS; validar nele não prova instalação limpa no Arch Linux. Registrar a
versão da imagem, kernel, compositor e pacotes quando essa validação ocorrer.
Fedora, Ubuntu, outras distribuições, outras arquiteturas e sistemas sem
systemd estão explicitamente fora do escopo atual.

Testar Hyprland e Labwc como perfis separados. Manter a integração Mango
existente, mas só declarar suporte reproduzível após validação equivalente.
Não exigir que o usuário troque de compositor para instalar a shell.

| Camada | Responsabilidade |
| --- | --- |
| Pacote da shell | QML, scripts, assets, runtime e ferramentas declaradas |
| Preferências | Tema, cidades, atalhos configuráveis e opções do usuário |
| Sistema hospedeiro | GPU, sessão Wayland, D-Bus, serviços e permissões |
| Perfil de compositor | Inicialização, atalhos e capacidades disponíveis |
| Perfil de máquina | Monitores, dispositivos, impressoras e ajustes locais |

Blur e outras capacidades do compositor devem ter comportamento explícito;
ausência de um recurso não pode ser apresentada como funcionamento completo.

## Etapas e critérios de aceitação

O [plano de empacotamento Arch](arch-packaging-plan.md) detalha destinos,
relocação, receita, sessão e migração. A relocação mínima dos caminhos é
pré-requisito da prova de pacote; as demais ferramentas de instalação e
migração vêm depois dessa prova. O produto chama-se **Lume**; Quickshell é o
runtime, e o pacote Arch planejado chama-se `lume-shell`.

Primeira implementação de prova: launcher `lume-shell`, unidade de usuário
separada, PKGBUILD com build local de staging e suporte XDG para workspaces,
wallpaper, preferências de CPU, waypaper, temas Qt e capturas de tela. O doctor
aceita as unidades Lume e Quickshell. Isso ainda não equivale a instalação,
validação ou migração do host; consulte [o estado e os limites do pacote](arch-packaging-plan.md).

### 1. Inventário e contrato de suporte

- [x] Fazer o mapeamento estático inicial de imports QML, famílias Python,
  ferramentas por capacidade, fontes/assets, serviços e arquivos externos;
  ver [dependency-inventory.md](dependency-inventory.md).
- [ ] Completar a enumeração de executáveis e módulos usados em caminhos
  condicionais; confirmar consumidores, dependências obrigatórias/opcionais e
  versões mínimas. O inventário atual ainda é estático e não fixa versões.
- [x] Criar o manifesto inicial `data/dependencies.json` (schema 1) para
  comandos-base, ferramentas por recurso e alternativas; `doctor.sh` valida e
  consome essas entradas. Versões dos pacotes Arch, versões mínimas, módulos
  Qt/QML e imports Python continuam pendentes.
- [x] Associar os comandos já manifestados aos nomes de pacotes Arch e indicar
  origem oficial, AUR ou externa. Essa correspondência não fixa versões e não
  cobre ainda dependências Python, plugins Qt/QML, serviços e recursos por
  compositor.
- [x] Inventariar os imports QML montados e as bibliotecas Python externas
  usadas pelos helpers; registrar os pacotes Arch correspondentes. A presença
  dinâmica dos módulos ainda precisa ser validada em Arch limpo.
- [x] Separar requisitos de comando por perfil Hyprland, labwc e Mango e
  registrar serviços de sistema opcionais por capacidade; o doctor consome as
  verificações de executáveis do perfil ativo. Ativação real de serviços e a
  disponibilidade dos pacotes AUR ainda não foram validadas em Arch limpo.
- [x] Identificar os principais caminhos pessoais, comandos Arch e
  pressupostos de sessão no inventário inicial.
- [x] Revisar os guias de instalação contra o código para wallpaper, agentes
  de rede e escolha entre TLP e power-profiles-daemon. Os guias agora usam a
  galeria do Theme Studio como fluxo padrão e deixam Waypaper opcional; o
  perfil labwc não instala `swaylock`/`wlr-randr` sem uso; os perfis Arch
  documentam NetworkManager sem `nm-applet` e PPD como perfil padrão sem TLP.
  O limite ThinkPad foi isolado em helper Polkit, e os guias registram que as
  otimizações adicionais de USB/runtime PM do TLP não são reproduzidas pelo PPD.
  O serviço de energia também restaura o limite ao desconectar e replica a
  troca AC/bateria dos perfis e modos de suspensão configurados no host.

Entrega: manifesto de dependências e matriz de capacidades versionados.
Aceitação: cada recurso montado tem dependências e comportamento de ausência
documentados; nenhuma dependência necessária fica apenas no yadm pessoal.

### 2. Prova de empacotamento Arch com versões identificáveis

- [ ] Prototipar uma receita `PKGBUILD` para a shell e declarar dependências
  Arch, incluindo Quickshell, Qt/QML e módulos Python. Registrar as versões
  utilizadas e eventuais patches necessários às APIs usadas pela shell.
- [x] Versionar a receita Arch do Hyprlock customizado de digital, com commit
  upstream, checksums, patch, teste de regressão e modelos separados de
  integração do leitor deste host; suporte fora do Arch e aceitação em
  hardware continuam pendentes.
- [ ] Testar em uma VM Arch Linux limpa, com outro usuário.
- [ ] Verificar plugins QML/Qt, fontes, renderização acelerada, D-Bus,
  PipeWire e resolução dos executáveis pelo launcher.
- [ ] Fixar fontes e assets redistribuíveis e conferir suas licenças.
- [ ] Registrar decisão de adotar ou revisar o empacotamento a partir dessa
  prova; não expandir instalação antes de resolver incompatibilidades.

Aceitação: a receita instala e inicia em Arch Linux limpo sem ajustes manuais
ocultos; dependências externas restantes são explicitamente identificadas.

### 3. Separar instalação e dados pessoais

- [ ] Tornar o pacote instalável fora de `~/.config/quickshell`, com caminhos
  relativos ao pacote e diretórios XDG para configuração, estado e cache.
- [ ] Incluir templates de serviços e integração de sessão hoje externos.
- [ ] Permitir overrides pessoais sem alterar arquivos do pacote.
- [ ] Separar ajustes ThinkPad, monitores, impressoras e caminhos pessoais.
- [x] Remover caminhos `/home/USER` do perfil Hyprlock atual, inicializar
  seu include de cores junto à paleta e documentar requisitos do host; isso
  ainda não empacota o perfil.
- [ ] Versionar o formato das preferências e suas migrações; preservar a
  possibilidade de retorno após atualização.

Aceitação: usuário novo instala sem yadm nem arquivos do autor; o runtime
não grava no pacote; instalação atual continua funcionando durante a migração.

### 4. Diagnóstico e integração com o hospedeiro

- [ ] Expandir `doctor.sh` a partir do manifesto, distinguindo dependência
  obrigatória quebrada de integração opcional indisponível.
- [x] No perfil Hyprland/labwc, diagnosticar Hyprlock, seu arquivo de
  configuração, helper de bateria e include de cores inicial.
- [ ] Verificar serviços, permissões, ambiente da sessão e capacidades do
  compositor, com orientações específicas para o alvo Arch Linux.
- [ ] Garantir uma única instância da shell e inicialização/encerramento
  associados à sessão; tratar conflitos com servidores de notificações.
- [ ] Documentar NetworkManager, BlueZ, PipeWire, Polkit, portais e energia
  como integrações do sistema, sem iniciar daemons concorrentes.

Aceitação: dependência ausente produz diagnóstico acionável; controles
indisponíveis têm estado explícito; encerrar e entrar na sessão não duplica
processos nem conserva ambiente de outro compositor.

### 5. Recursos específicos de distro

- [ ] Manter o provedor pacman/AUR como integração do alvo Arch e declarar
  seus pacotes e requisitos no manifesto.
- [ ] Manter Flatpak e demais provedores opcionais independentes.
- [ ] Detectar capacidades de energia e luz noturna sem impor hardware ou
  serviços pessoais; não substituir backends estáveis sem necessidade.
- [ ] Preservar autorização Polkit e nunca elevar a shell inteira.

Aceitação: recursos Arch funcionam no alvo; ausência de provedores opcionais
não impede iniciar a shell; fixtures e testes cobrem respostas e falhas reais.

### 6. Instalação, atualização e recuperação

- [ ] Oferecer entrada documentada para executar/instalar uma versão fixada.
- [ ] Tornar instalação idempotente, com pré-verificação e backup de arquivos
  conflitantes; não sobrescrever preferências silenciosamente.
- [ ] Separar instalação do pacote de alterações privilegiadas do sistema.
- [ ] Documentar atualização, rollback, desinstalação e recuperação de falhas.
- [ ] Exportar preferências portáveis e referências a assets, excluindo por
  padrão credenciais, clipboard, notificações e outros históricos pessoais.
- [ ] Manter yadm como opção de preferências, não requisito de instalação.

Aceitação: instalar duas vezes não duplica serviços; atualização e rollback
preservam dados compatíveis; desinstalar remove somente o que foi instalado.

### 7. Validação e publicação

- [ ] Executar validação estrutural e testes existentes em ambiente fixado.
- [ ] Testar instalação e sessão real em uma VM limpa de Arch Linux, com
  versões registradas de imagem, compositor, shell e dependências.
- [ ] Cobrir barra, Spotlight, clipboard, toasts, histórico, áudio, rede,
  temas, workspaces, bloqueio e retomada, conforme capacidades disponíveis.
- [ ] Comparar screenshots com escala, fontes, tema e resolução controlados.
- [ ] Verificar em hardware real GPU, Bluetooth, bateria, suspensão e
  múltiplos monitores; distinguir esses resultados dos testes em VM.
- [ ] Publicar versão e manifesto com evidências e limitações conhecidas.

Aceitação final: uma pessoa em instalação limpa de Arch Linux consegue instalar
uma versão publicada seguindo apenas a documentação, sem copiar arquivos
adicionais da máquina do autor. Containers podem validar helpers e builds, mas
não contam como validação da sessão gráfica, suspensão ou hardware.

## Ordem de execução e controle de progresso

Executar 1 → 2 → 3 → 4 → 5 → 6 → 7, em mudanças pequenas e revisáveis.
A primeira entrega funcional deve ser a prova em Arch Linux limpo; evitar
construir instaladores completos antes de validar o runtime empacotado.

Para cada etapa, registrar separadamente: código implementado, testes
automatizados, sessão gráfica validada e hardware verificado. Não marcar
suporte a uma distro como concluído apenas porque o pacote compilou.

Estado em 05/11/2026: etapa 1 em andamento. O manifesto inicial já alimenta o
doctor para requisitos de comandos, mas ainda não substitui o inventário
completo. A revisão dos guias de wallpaper, NetworkManager e energia foi
concluída; faltam enumerar dependências e versões dos pacotes Arch. A prova de
empacotamento e validação em uma instalação limpa de Arch Linux não começaram.
