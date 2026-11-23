# ReGreet para o login do Lume

Este host usa `greetd` como display manager. A interface anterior era
`tuigreet`, configurada em `/etc/greetd/config.toml`. Os arquivos de origem
deste setup ficam em `packaging/arch/greetd/`.

O novo greeter é ReGreet, iniciado pelo Cage em uma sessão Wayland separada.
O painel usa a paleta Chameleon e o wallpaper ativo. O Lume atualiza esses
arquivos em `/var/lib/lume-greeter/` sempre que o wallpaper ou as cores são
aplicados. A pasta pertence ao usuário da sessão, usa o grupo `greeter` para
leitura e não expõe a pasta pessoal.

## Instalação e teste

No Arch, instale as dependências opcionais e rode o assistente do próprio Lume:

```sh
sudo pacman -S --needed greetd-regreet cage
lume-shell greeter install
```

O pacote instala os modelos em `/usr/share/lume-shell/greetd/`. O assistente
cria `/var/lib/lume-greeter` como diretório privado do usuário da sessão e
legível pelo grupo `greeter`, sincroniza o wallpaper e a paleta atuais e salva
uma cópia da configuração de greetd antes de substituí-la. Ele não reinicia o
greetd automaticamente; a sessão atual continua aberta e a configuração nova
entra em vigor no próximo início do serviço. Para ativar imediatamente, salve
seu trabalho e rode `sudo systemctl restart greetd`, que encerra a sessão
gráfica atual. `lume-shell greeter install --restart` faz essa reinicialização
como parte da instalação.

O arquivo `config.toml` inicia `dbus-run-session cage -s -mlast -d -- regreet`
como usuário `greeter` e aponta para o CSS compartilhado. `regreet.toml`
configura o wallpaper, o relógio em português e as ações de energia. O Lume
atualiza o JPEG e o CSS compartilhados quando o wallpaper ou as cores mudam;
assim o greeter não depende de um wallpaper fixo nem precisa ler a pasta home.

Para pré-visualizar sem alterar o serviço, use `regreet --demo` com o arquivo
de configuração e o CSS do Lume; o modo demo usa autenticação fictícia.

## Recuperação

O assistente guarda as configurações anteriores como
`/etc/greetd/config.toml.before-lume-shell` e
`/etc/greetd/regreet.toml.before-lume-shell`. Se o greeter não iniciar, entre
em um TTY (`Ctrl`+`Alt`+`F2`), faça login e restaure a cópia do `config.toml`;
depois reinicie o greetd. O serviço e o backend PAM permanecem os mesmos.
