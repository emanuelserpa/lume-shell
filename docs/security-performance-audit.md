# Revisão de segurança, memória e desempenho

Data: 19/11/2026. Código revisado: `5ea175f`, pacote instalado `0.1.2-1`.
Escopo: inspeção dirigida de código, permissões, logs e amostragem passiva do
host. Os achados abaixo descrevem o baseline observado antes das correções no
worktree. A seção de andamento registra o que já foi alterado.
Não foram executados testes destrutivos de lock, suspensão, autenticação ou OOM.
Não houve leitura do conteúdo pessoal do clipboard ou das notificações.

## Evidências do host

- Processo principal observado: PID 2336971, aproximadamente 8h51 de vida.
- Serviço: `MemoryCurrent` 550981632 bytes (525 MiB), `MemoryPeak`
  1030225920 bytes (983 MiB), `NRestarts=0`. Esses valores são do cgroup,
  não apenas do processo principal, e não demonstram vazamento por si só.
- Quatro amostras entre 08:33:31 e 08:34:01: RSS 470352 → 469636 KiB,
  PSS 368706 → 368208 KiB; 23 threads e 64 descritores em todas as amostras.
  Não houve crescimento nessa janela curta. Ainda falta teste prolongado.
- Host com 8,9 GiB disponíveis; PSI de memória `avg10=0.00` nessa consulta.
  Não foi observada pressão atual suficiente para atribuir travamentos à RAM.
- Histórico de notificações: aproximadamente 887 MiB em disco; 11.595 PNGs
  `notification-*`, somando 905566304 bytes (864 MiB). Nenhum desses PNGs
  tinha mais de 30 dias. RAM, disco e memória de GPU devem ser medidos separados.
- Logs de instalação às 08:16:52 e 08:17:40 registram recarga automática e
  `shell.qml: File not found`. Na primeira há recuperação explícita; no trecho
  inspecionado não há confirmação de recuperação após a segunda.

## Achados confirmados e limites

### A1 — Cache de imagens sem orçamento e limpeza custosa (alta)

Em `scripts/notification_store.py:136`, a limpeza consulta referências no banco
e percorre todos os PNGs. Só apaga órfãos com mais de 30 dias, sendo chamada
em diversas operações de escrita e remoção. O limite de 2.000 registros do
banco não limita o diretório de imagens. A condição explica a possibilidade de
acúmulo; ainda não foi contado quantos arquivos atuais são órfãos.

Impactos: disco, trabalho de filesystem repetido e retenção de imagens após
remoção do histórico. Não confundir isso com comprovação de vazamento de RAM.

### A2 — Retenção de estado de notificações (alta)

`services/NotificationState.qml` acrescenta entradas a `cachedNotificationImages`
sem caminho explícito de remoção, inclusive em `clearAll()`. Cada imagem nova
também copia o mapa completo. A retenção de chaves/caminhos é confirmada;
não há evidência de que cada entrada retenha uma textura inteira.

O conjunto `retainedImageNotifications` tem limite de 500 objetos, mas falhas
de captura/gravação não liberam imediatamente a referência. A lista nativa de
notificações rastreadas não mostra o mesmo limite explícito do histórico SQLite.
É necessário medir o comportamento dos QObjects do Quickshell em uma instância
isolada antes de alterar o ciclo de vida e quebrar ações ou imagens.

### A3 — Atualização do pacote disputa com hot reload (alta)

O shell principal acompanha alterações de arquivos enquanto o pacman substitui
o pacote. Os erros observados são compatíveis com essa janela de substituição.
O lockscreen já desativa o watcher; o shell instalado precisa de uma política
própria para carregar somente a árvore completa após a transação.

### A4 — Privacidade dos caches derivados do clipboard (alta, condicional)

`scripts/launcher-data.py:_save_clipboard_index` e os escritores em
`scripts/clipboard_store.py` não impõem permissões privadas ao índice temporário,
índice final e thumbnails. No host: índice 0644 e diretório de thumbnails 0755.
A pasta ancestral `.cache` é 0700, impedindo acesso por outros usuários comuns
neste host. Em outro XDG_CACHE_HOME, essa proteção não está garantida.
O banco e blobs principais já ficam em diretórios 0700.

### A5 — Processos de consulta sem prazo global (média)

`components/CommandJson.qml` tinha watchdog de início de dois segundos, mas não
prazo máximo depois de `started`; os coletores de saída também não tinham limite
explícito. Vários helpers já usam timeouts internos, mas isso não cobria todo
o contrato. Um helper bloqueado podia impedir futuras consultas, e saída excessiva
podia aumentar a memória. Não foi observado helper preso nesta inspeção.

### A6 — Imagens grandes e trabalho em superfícies ocultas (média, hipótese)

O wallpaper de `lockscreen/LockSurface.qml` e a imagem ambiente de
`bar/MediaPopup.qml` não especificam `sourceSize`. Isso permite decodificação
maior que a área exibida; o custo depende do arquivo, backend e cache de Qt.
Os cartões de notificação já limitam imagens e a captura usa 256×256.
O monitor básico consulta a cada 5 segundos por instância de barra; os sensores
detalhados são condicionados ao popup aberto. Medir vários monitores antes de
propor centralização ou reduzir frequência.

### A7 — Segurança do lock e cadeia de release: verificação incompleta

Pontos positivos observados: desbloqueio condicionado a `PamResult.Success`,
`secure` e `locked`; senha fora de argv e logs nos caminhos inspecionados;
campo mascarado sem atraso e limpeza do valor pendente; lock sem hot reload.
Isso não constitui certificação equivalente à do Hyprlock.

Faltam testes em compositor isolado para falha/ausência de PAM/fprintd, morte do
processo, perda do monitor de logind, múltiplos monitores e suspensão. A senha
passa por strings QML/JS: atribuir string vazia não garante zeragem física de
todas as cópias da credencial. Avaliar esse requisito antes de propor backend
nativo; não há bypass de autenticação demonstrado nesta revisão.

O workflow de release constrói pacotes, mas não executa o validador; Actions
usam tags móveis. Os documentos divergem sobre gate de qualidade, versão,
licença e aprovação. A existência do Environment `release` não prova revisão
obrigatória; a configuração remota não foi auditada nesta rodada.

## Plano de implementação e aceitação

### Andamento

- **A1 — imagens:** implementado no worktree um limite de 256 MiB e 2.000
  imagens referenciadas, retenção das imagens mais recentes, remoção segura de
  órfãos com mais de 15 minutos e limpeza amortizada (no início, a cada 100
  operações ou após 10 minutos). Quando uma imagem antiga é descartada, o texto
  da notificação continua no histórico. A validação e instalação foram concluídas;
  no primeiro início, o banco tinha 2.000 notificações sem imagem vinculada e o
  cache continha cerca de 11.595 PNGs órfãos (864 MiB), que foram removidos.
- **A2 — estado QML:** o mapa de imagens fica limitado a 500 entradas e é limpo
  ao apagar o histórico.
- **A3 — recarga:** o wrapper da instalação em `/usr/share/lume-shell` desativa
  o watcher de arquivos; checkouts de desenvolvimento mantêm hot reload.
- **A4 — clipboard:** diretório de cache/thumbnails fica em 0700; índice e
  marcador de mudança ficam em 0600, inclusive arquivos temporários. Testes
  cobrem diretório público, arquivo antigo permissivo e destino por symlink.
- **A5 — consultas:** cada `CommandJson` usa um wrapper com prazo configurável
  (60 s por padrão), encerra o grupo de processos ao expirar e limita stdout e
  stderr a 64 KiB cada. Testes verificam passagem normal, timeout, limite de
  saída e o comportamento integrado no Quickshell.
- **A6–A7:** permanecem no plano abaixo; não foram alterados nesta rodada.

As correções estão implementadas e passaram pela validação local; ainda falta
observar o uso prolongado no host. O pacote `0.1.3-1` está instalado e o serviço
está ativo, sem reinícios. Sete segundos após o restart, o cgroup marcava
317,5 MiB; esse ponto inicial não é comparável ao baseline de uma sessão com
quase nove horas e não demonstra redução nem vazamento.

1. **Privacidade e atualização segura (P0).** Validar em fixture com umask 022,
   cache ancestral público, arquivos preexistentes e links simbólicos. Atualizar
   o pacote em teste e confirmar que não há recarga da árvore parcial nem
   interrupção de um lock em curso.
2. **Limitar memória e disco das notificações (P1).** Confirmar limpeza de
   órfãos e orçamento em testes de rajadas, DND, imagens, remoção e recuperação
   do store. Verificar que imagens em captura não são removidas e que o texto
   histórico permanece disponível quando a imagem antiga sai do cache.
3. **Medir e controlar recursos (P1).** Teste isolado com 30 ciclos de abrir e
   fechar Spotlight, mídia e notificações; medir RSS/PSS, cgroup, descritores,
   threads e filhos antes/depois de repouso. Fazer teste de 2 horas e observar
   um dia de uso normal. Separar pico temporário, platô de cache e crescimento
   contínuo; não chamar RSS alto de leak sem evidência. Definir limiares a partir
   de três execuções de referência. O timeout e o limite de saída foram
   implementados; falta medir o ciclo longo de UI e comparar com baseline.
4. **Lockscreen e permissões elevadas (P1).** Matriz de falhas em sessão
   descartável: senha errada, ausência/queda de fprintd, aborto concorrente,
   suspend/resume, queda do logind monitor e morte do lock. Exigir que nenhuma
   falha conceda acesso e documentar recuperação. Revisar separadamente helpers
   pkexec/sudo e instalação ReGreet com destinos/symlinks hostis em fixtures.
5. **Renderização e polling (P2).** Medir imagens 4K/8K, popups fechados e dois
   monitores; limitar decode à resolução necessária e suspender trabalho oculto
   quando a medição mostrar ganho. Preservar o pool fixo de players MPRIS e a
   aparência atual. Comparar CPU em intervalos, latência e memória com baseline.
6. **Entrega verificável (P2).** Reconciliar docs; propor reativação da qualidade
   remota, antes suspensa por decisão do usuário, corrigindo as falhas conhecidas.
   Fixar Actions por SHA e verificar proteções reais de release. Para próximos
   lançamentos, validar o commit e não mover tags já publicadas. Distribuição
   continua pelo GitHub, sem publicar no AUR.

Cada etapa deve ter mudança pequena, regressões relevantes e validação offline
antes de instalar. Testes destrutivos ficam em ambiente isolado. Não apagar
histórico/caches pessoais nem reiniciar o shell apenas para produzir números.
