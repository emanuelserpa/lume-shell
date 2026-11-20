# Pacote Arch Linux

O pacote `lume-shell` instala o código em `/usr/share/lume-shell`, o comando
`lume-shell` e a unidade de usuário `lume-shell.service`. Quickshell é instalado
separadamente pelo pacote do runtime.

As integrações de energia também pertencem ao pacote: os helpers `lumeshell-*`,
as regras Polkit e as unidades `lumeshell-power-source-policy.service` e
`lumeshell-cpu-boost-restore.service`. A política acompanha AC/bateria e a
restauração de boost roda no login do usuário. O pacote habilita essas unidades.

Também fornece os perfis PAM `/etc/pam.d/lumeshell-lock` e
`/etc/pam.d/lumeshell-lock-password`, além do protótipo de lockscreen.
`lume-shell lock` inicia o bloqueio nativo do Lume; o Hyprland pode usá-lo no
atalho e no `hypridle`. Com `fprintd` instalado, a digital segue ativa enquanto
a pessoa também pode escolher “Usar senha”. O pacote trata os dois arquivos
PAM como configuração pelo pacman.

## Build local

Na raiz do checkout:

```sh
cd packaging/arch
makepkg --cleanbuild
```

O build local usa a árvore atual, exclui `.git`, caches, arquivos de preferência
do usuário e resultados de builds anteriores. O build não instala o pacote nem
reinicia o shell; o script de instalação do pacote ativa apenas as unidades de
energia do Lume.

## Comandos do Spotlight

O comando `lume-shell` inicia a shell. Subcomandos enviam ações à instância em
execução:

```sh
lume-shell spotlight toggle
lume-shell spotlight clipboard
lume-shell spotlight actions
lume-shell lock
```

Para uma instância de desenvolvimento, defina
`LUME_SHELL_CONFIG="$HOME/.config/quickshell"`.

## Releases

O workflow de release compila a tag exata `vX.Y.Z` e anexa o pacote Arch à
GitHub Release. A validação em uma instalação Arch limpa deve preceder a
primeira distribuição do pacote. O pacote registra a licença MIT e instala o
arquivo `LICENSE` em `/usr/share/licenses/lume-shell/LICENSE`. Ativos e
dependências de terceiros mantêm suas licenças próprias.

### ReGreet opcional

O pacote inclui modelos para o ReGreet sem substituir a configuração de login
automaticamente. Instale `greetd-regreet` e `cage` e execute
`lume-shell greeter install`. O assistente preserva a configuração existente,
prepara os assets legíveis pelo greeter e mantém o wallpaper e as cores em
sintonia com o Lume. Use `--restart` somente quando puder encerrar a sessão
gráfica atual.
