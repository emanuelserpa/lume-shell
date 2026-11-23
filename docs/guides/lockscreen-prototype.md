# Protótipo de bloqueio do Lume

Este protótipo testa uma superfície `ext_session_lock_v1` por monitor e
autenticação PAM. A tela reúne wallpaper, relógio, data, clima, cartão MPRIS e
uma ilha que reutiliza as pills e popups de bateria e áudio da barra. O
protótipo pode ser iniciado com `lume-shell lock`; no Hyprland, o atalho e o
`hypridle` podem encaminhar o bloqueio para esse comando. O Hyprlock continua
instalado como fallback.

## Composição da tela

O ponto de entrada `lockscreen.qml` fica na raiz para que os serviços existentes
resolvam os caminhos relativos ao shell. A tela usa o wallpaper selecionado,
relógio e data, a previsão já fornecida por `WeatherState` e um cartão do player
MPRIS ativo com capa, progresso e controles. A data fica acima do relógio grande,
seguindo a hierarquia da tela bloqueada do macOS; o clima vem abaixo do relógio e
o cartão de música fica centralizado sob esse conjunto. A área de autenticação
fica no rodapé. A ilha compacta no canto superior direito reutiliza os
componentes `Battery` e `Audio` da barra, ampliados levemente; clicar no pill
de som tenta abrir o popup PipeWire, o botão direito alterna mute e a rolagem ajusta o
volume; no lockscreen, uma área de entrada no contêiner da ilha mantém essas
ações alinhadas ao pill ampliado e ancora o popup nesse mesmo contêiner. A
bateria também tenta abrir o popup real de UPower. A capa pode tentar abrir o
popup MPRIS para controles extras. Esses popups são `PopupWindow` comuns e não
têm abertura garantida a partir da superfície de lock; controles essenciais
precisam ficar inline no lock ou usar uma superfície comprovadamente
compatível. Os players MPRIS podem ser escolhidos pelos indicadores em bolinhas
exibidos diretamente no cartão de mídia. O ícone
de energia no fim da ilha abre um menu desenhado dentro da
própria superfície segura do lockscreen, com a ação Suspender. Ela usa o
despachante de sessão existente, e o bloqueio permanece ativo durante a
suspensão. Quando o lock fica seguro, o PAM inicia o leitor de digital e o
mantém ativo sem prazo ou limite de
leituras. Assim, basta colocar o dedo no sensor a qualquer momento enquanto a
tela estiver bloqueada. O campo de senha já fica focado para digitação e Enter
abre uma conversa PAM separada para validá-la, enquanto a conversa de digital
permanece ativa. É possível encostar o dedo durante a digitação ou validação da
senha. Enter sem texto mantém a leitura ativa. A autenticação fica numa
superfície de vidro compacta, alinhada ao cartão de mídia, com o estado do
sensor no cabeçalho e o campo de senha em formato de pill. A paleta vem de
`Theme.qml`.

Essa composição foi vista em uma prévia fullscreen normal, sem bloquear a
sessão. O lock real foi testado em um monitor e a autenticação por senha foi
aceita. Suspensão/retomada e múltiplos monitores continuam sem teste.

Para visualizar a composição em uma janela de tela cheia sem bloquear a sessão,
execute `./scripts/run-lockscreen-preview.sh`. Essa prévia usa autenticação
simulada e não pode desbloquear nem bloquear o computador. Pressione Escape para
fechá-la.

## Como testar manualmente

Na sessão Wayland do usuário, com a tela desbloqueada e sem outro bloqueador
ativo, execute:

```sh
lume-shell lock
```

Durante o desenvolvimento, `./scripts/run-lockscreen-prototype.sh` inicia a
cópia do checkout.

Isto bloqueia a sessão imediatamente. O perfil PAM mantém a digital ativa; a
senha é uma alternativa simultânea e Escape não desbloqueia. O protótipo
desativa hot reload para evitar que uma edição destrua o objeto de bloqueio
ativo. Para sair, autentique-se com sucesso.

**Não encerre o processo à força para sair do teste.** Se o cliente terminar
antes de liberar o lock, o compositor compatível mantém a sessão bloqueada e
exibe uma cor sólida; pode ser necessário recuperar a sessão pelo TTY. Não
execute este comando enquanto Hyprlock já estiver bloqueando: apenas um
`WlSessionLock` pode estar ativo.

## Autenticação

O protótipo usa os serviços PAM dedicados `lumeshell-lock` e
`lumeshell-lock-password`, fornecidos pelo pacote em `/etc/pam.d/`. O primeiro
mantém `pam_fprintd` esperando indefinidamente (`max-tries=-1 timeout=-1`), sem
misturar uma conversa de senha; o segundo contém apenas a pilha `login`. A
interface executa essas conversas PAM
em paralelo para aceitar digital e senha ao mesmo tempo. Isso contorna a regra de
`system-auth` que restringe a digital a `sudo` e `polkit-1`, sem alterar
`system-auth`, `login` ou `hyprlock`. O módulo de digital é opcional
(`fprintd`); sem ele, a tela continua permitindo senha. As linhas `account` e
`session` estão presentes nos perfis, mas o `PamContext` do Quickshell executa
somente `auth`: não há garantia de verificação de expiração da conta ou de
políticas de sessão por essas linhas.

A senha fica somente na memória durante a solicitação e é limpa logo que
enviada ao PAM. O lock só é liberado com `PamResult.Success`; falhas, erros e
encerramento do processo não liberam a sessão. O PAM inicia depois que
`WlSessionLock.secure` confirma que o compositor cobriu as telas.

O comando foi testado pelo Hyprland com o pacote instalado e a digital
desbloqueou a sessão. O atalho `SUPER+L`, o timeout de cinco minutos e o
bloqueio antes da suspensão chamam `lume-shell lock`, com Hyprlock como reserva
se o Lume não iniciar. A leitura contínua após a mudança de perfil PAM depende
de teste físico do sensor; o fallback de senha e a retomada após suspensão
também precisam de uma rodada de teste dedicada.

Após a suspensão, o `fprintd` pode reiniciar e invalidar a conversa PAM que
estava aberta. O lock acompanha `PrepareForSleep` pelo `gdbus`; na retomada,
aborta a conversa biométrica antiga, espera um segundo e inicia outra. A
conversa biométrica fica isolada da pilha de senha; outras falhas continuam
com novas tentativas em intervalo crescente até 30 segundos, sem liberar a
sessão. O campo de senha fica visível e recebe foco quando o lock fica seguro,
então é possível digitar e pressionar Enter sem escolher um modo ou clicar no
campo.

## Revisão de segurança — 18/11/2026

Revisão do código pendente, dos perfis PAM e do comando de inicialização;
não equivale a uma auditoria independente do compositor, Qt ou Quickshell.

- A única atribuição que libera o lock exige `PamResult.Success`, sessão ainda
  bloqueada e confirmação `secure`. O teste isolado executa essa função com
  substitutos inertes, cobrindo sucesso, falhas, tipos inesperados e estados
  do compositor. Não inicia PAM nem bloqueia a sessão real.
- A entrada real desativa `Quickshell.watchFiles` explicitamente. A variável
  de ambiente usada pelo script de desenvolvimento não é a garantia disso.
- Sucesso por senha ou digital limpa a senha pendente e o campo visual antes
  de abortar as conversas PAM. Strings QML não permitem garantir zeragem física
  da memória. O campo solicita ao método de entrada que não memorize nem
  sugira conteúdo sensível. Não há senha em argv, arquivo ou log do Lume.
- O mixer do lock não oferece nem executa o lançamento externo de
  `pwvucontrol`. Volume, mute, controles de mídia e energia são ações
  intencionalmente acessíveis sem autenticação. Mídia, clima e nomes de players
  podem revelar informação na tela bloqueada.
- Título e artista no cartão são texto simples. Capas e wallpaper ainda passam
  pelos decodificadores de imagem do Qt; o lock compartilha a superfície de
  ataque dos widgets e serviços importados.
- A leitura de digital sem limite foi mantida conforme a preferência do
  usuário. A política de tentativas difere da senha e não é apresentada como
  equivalente a um limite de tentativas biométricas.
- O `PamContext` executa apenas `auth`, conforme a
  [documentação oficial](https://quickshell.org/docs/v0.3.2/types/Quickshell.Services.Pam/).
  As linhas `account`/`session` não garantem expiração ou restrições de conta.
- Em um compositor compatível, a saída do cliente sem desbloqueio deixa a
  sessão bloqueada, conforme o contrato de
  [WlSessionLock](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/WlSessionLock/).
  Crash, suspensão, remoção de monitor e recuperação por TTY não foram
  provocados nesta revisão. O menu de energia fica na própria
  `WlSessionLockSurface`: o protocolo permite garantir as superfícies de lock,
  mas não garante janelas popup comuns durante a sessão bloqueada. Um caso do
  Quickshell registra rejeição de `xdg_popup` sem pai válido quando um popup
  tenta nascer a partir da superfície de lock.

## Superfícies e popups no lockscreen

`WlSessionLock` cria uma `WlSessionLockSurface` própria por monitor. Essa
superfície é a camada garantida pelo protocolo enquanto a sessão está bloqueada;
uma janela `PopupWindow` comum é outra superfície e pode não ter um pai Wayland
válido para ser aberta a partir dela. O sintoma pode variar por compositor: o
popup pode não aparecer ou o pedido de `xdg_popup` pode ser rejeitado. Portanto,
não use a visibilidade de um popup comum como única forma de acessar um controle
no lockscreen.

Controles essenciais e seletores do lock ficam dentro da própria
`WlSessionLockSurface`: os pontos MPRIS ficam no cartão de mídia e o menu de
suspensão é desenhado na ilha. Popups comuns podem continuar sendo usados na
barra desbloqueada. Se for necessário um popup no lock, ele precisa ser
implementado e testado com um mecanismo explicitamente compatível com a
superfície de sessão bloqueada; apenas ancorar um `PopupWindow` a um item do
lock não fornece essa garantia. Veja o contrato do
[WlSessionLock](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/WlSessionLock/)
e o comportamento documentado para
[WlSessionLockSurface](https://quickshell.org/docs/v0.2.1/types/Quickshell.Wayland/WlSessionLockSurface/).
