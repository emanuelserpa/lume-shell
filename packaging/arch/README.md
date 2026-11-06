# lume-shell para Arch Linux

Esta receita empacota a shell como `lume-shell`; Quickshell continua sendo o
runtime fornecido pelo pacote Arch `quickshell`. O pacote instala somente o
código em `/usr/share/lume-shell`, um launcher e uma unidade de usuário. Não
instala nem habilita compositores, serviços de hardware, helpers privilegiados
ou integrações AUR. `python-pillow` é dependência obrigatória porque a shell usa
a extração de cores do wallpaper na experiência de temas.

## Build local da árvore atual

Na raiz do checkout:

```sh
cd packaging/arch
env _local_source="$PWD/../.." makepkg --cleanbuild
```

O modo local copia a árvore de trabalho para o staging e exclui `.git`, caches,
`workspaces.json` pessoal e a preferência local de CPU boost. O resultado é
um pacote para inspeção; o build não instala nem reinicia o shell.

## Comandos do Spotlight

O launcher `lume-shell` mantém o início da shell sem argumentos e oferece
atalhos para o Spotlight que já está em execução:

```sh
lume-shell spotlight clipboard
lume-shell spotlight actions
lume-shell spotlight emoji
lume-shell spotlight search "Firefox"
```

Os comandos disponíveis são `open`, `toggle`, `clipboard`, `actions`, `theme`,
`config`, `emoji`, `kill`, `windows` e `search <texto>`. O IPC usa por padrão a
configuração instalada em `/usr/share/lume-shell`; para uma instância de
desenvolvimento, defina `LUME_SHELL_CONFIG="$HOME/.config/quickshell"`.
O serviço `lume-shell.service` continua iniciando a shell diretamente.

## Build de uma revisão publicada

Sem parâmetros, o PKGBUILD usa o checkout local. Para buscar uma revisão
remota, forneça `_release_commit` com o hash completo e confira o conteúdo com
`makepkg --printsrcinfo` e `makepkg --verifysource`. A origem git é imutável pelo
commit; `SKIP` é usado porque makepkg não valida checksum de fonte VCS.

O workflow `.github/workflows/release-arch-package.yml` roda em cada push de
tag `vX.Y.Z`, constrói o pacote em `archlinux:base-devel` usando o commit exato
da tag e cria uma GitHub Release com o `.pkg.tar.zst` anexado. O token padrão
do Actions precisa de permissão `contents: write`. Antes da primeira tag
pública, defina a licença do projeto e atualize `license`/arquivos de licença;
esta receita ainda usa `custom` apenas para builds privados.

## Instalação e migração

Instalar o pacote não troca a sessão ativa. Antes de iniciar Lume, verifique a
unidade existente e evite executar `quickshell.service` junto com
`lume-shell.service`. A ativação é manual:

```sh
systemctl --user disable --now quickshell.service
systemctl --user daemon-reload
systemctl --user enable --now lume-shell.service
```

Para retornar ao checkout, pare e desabilite `lume-shell.service`, restaure a
unidade anterior a partir do backup e inicie-a. Dados do usuário ficam em XDG e
não são removidos ao desinstalar o pacote.

## Limites antes de publicar

O projeto ainda não declara uma licença no repositório; `license=('custom')`
serve apenas para o pacote privado local e a receita não deve ser publicada
antes de definir e incluir a licença. O histórico foi reiniciado; não há pin para commits do repositório anterior.
O workflow usa o checkout autenticado da tag, inclusive no repositório privado. A validação em
Arch limpo ainda falta.
