# Pacote Arch Linux

O pacote `lume-shell` instala o código em `/usr/share/lume-shell`, o comando
`lume-shell` e a unidade de usuário `lume-shell.service`. Quickshell é instalado
separadamente pelo pacote do runtime.

## Build local

Na raiz do checkout:

```sh
cd packaging/arch
makepkg --cleanbuild
```

O build local usa a árvore atual, exclui `.git`, caches, arquivos de preferência
do usuário e resultados de builds anteriores. Não instala o pacote nem reinicia
o shell.

## Comandos do Spotlight

O comando `lume-shell` inicia a shell. Subcomandos enviam ações à instância em
execução:

```sh
lume-shell spotlight toggle
lume-shell spotlight clipboard
lume-shell spotlight actions
```

Para uma instância de desenvolvimento, defina
`LUME_SHELL_CONFIG="$HOME/.config/quickshell"`.

## Releases

O workflow de release compila a tag exata `vX.Y.Z` e anexa o pacote Arch à
GitHub Release. A validação em uma instalação Arch limpa deve preceder a
primeira distribuição do pacote. O projeto ainda precisa declarar uma licença
própria antes que terceiros possam reutilizar o código.
