# Clipboard Manager (Native Backend)

## Visão Geral

O histórico do clipboard usa um backend nativo de Wayland integrado ao Quickshell.

A arquitetura combina:
- **`wl-paste --watch`**: observador de eventos de seleção do Wayland em tempo real;
- **`scripts/clipboard-daemon.py`**: daemon em Python responsável pela supervisão e orquestração;
- **`scripts/clipboard_store.py`**: camada de persistência com SQLite (modo WAL) e transações seguras;
- **Blob storage**: armazenamento eficiente de imagens em disco no diretório dedicado;
- **`launcher/Spotlight.qml`**: frontend estilo Raycast / Alfred (`#` ou `SUPER+C`) com visualização instantânea, split-view e preview rico.

Ao reabrir o histórico, a interface mantém os itens já carregados em memória
enquanto uma única consulta ao SQLite atualiza a lista. Na primeira abertura,
exibe o estado de carregamento até essa consulta terminar. O arquivo de índice
em cache continua disponível para compatibilidade, mas não é lido em paralelo
com a consulta ao abrir o launcher.

Enquanto o modo clipboard está aberto, a interface observa
`~/.cache/quickshell/clipboard-change`. O backend atualiza esse marcador depois
de confirmar uma mudança no SQLite; o Spotlight agrupa eventos próximos e
reconsulta o histórico, preservando a seleção pelo ID do item. Fora desse
modo, não há consultas periódicas ao banco.

O callback do observador consome o conteúdo enviado por `wl-paste --watch` no
`stdin` antes de consultar MIME e gravar o item. Isso impede que uma captura
PNG grande bloqueie o pipe e paralise eventos seguintes.

---

## Arquitetura do Sistema

```
Wayland Compositor (Hyprland)
            │
            ▼ (seleção alterada)
   wl-paste --watch
            │
            ▼
scripts/clipboard-daemon.py (--capture)
            │
            ├─► Detecção de tipos MIME (wl-paste --list-types)
            │   ├─► Imagens: captura blob e calcula SHA-256
            │   └─► Texto: decodifica UTF-8, sanitiza e classifica (link, código, texto)
            │
            ├─► Deduplicação & Prevenção de loop
            │   ├─► Idêntico ao topo atual: ignora (sem loop de restore)
            │   └─► Já existente no histórico: promove para o topo
            │
            └─► Persistência SQLite & Blobs
                    │
                    ▼
     ~/.local/share/quickshell/clipboard/
         ├── clipboard.db (WAL mode)
         └── blobs/<hash>.<ext>
```

---

## Localização dos Arquivos e Diretórios

### Diretório de Dados (XDG Data)
`~/.local/share/quickshell/clipboard/`
- **`clipboard.db`**: banco SQLite principal (com WAL journaling ativo).
- **`blobs/`**: imagens (`.png`, `.jpg`, `.webp`, `.svg`, etc.) nomeadas com seu hash SHA-256.
- **`daemon.lock`**: arquivo de lock com `fcntl.flock` para impedir instâncias concorrentes do daemon.

### Diretório de Cache (XDG Cache)
`~/.cache/quickshell/`
- **`clipboard-index.json`**: índice serializado mantido em cache para suporte e compatibilidade transparente com o frontend.

---

## Esquema da Tabela SQLite

```sql
CREATE TABLE clipboard_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at INTEGER NOT NULL,
    content_hash TEXT NOT NULL,
    primary_mime TEXT,
    mime_types TEXT NOT NULL,
    text_preview TEXT,
    full_text TEXT,
    line_count INTEGER DEFAULT 0,
    char_count INTEGER DEFAULT 0,
    item_type TEXT NOT NULL,
    blob_path TEXT,
    pinned INTEGER DEFAULT 0
);

CREATE INDEX idx_clipboard_created ON clipboard_items(created_at DESC);
CREATE INDEX idx_clipboard_hash ON clipboard_items(content_hash);
```

### Características dos IDs:
- **IDs Permanentes**: O campo `id` é um inteiro autoincrementado do SQLite.
- Diferente da lógica antiga de índices posicionais de listas, a remoção ou inserção de itens nunca altera o `id` de itens existentes, eliminando condições de corrida ou erros de itens que "voltam" ao apagar.

---

## Captura e Prioridade de Tipos MIME

Quando a área de transferência do Wayland é atualizada, os tipos disponíveis são consultados via `wl-paste --list-types`:

1. **Imagens** (Prioridade alta se presente):
   - `image/png`, `image/jpeg`, `image/webp`, `image/gif`, `image/bmp`, `image/svg+xml`.
   - Limite de segurança: até 25 MiB.
   - O arquivo original é gravado em `blobs/<hash>.<ext>`.
2. **Textos**:
   - `text/plain;charset=utf-8`, `text/plain`, `UTF8_STRING`, `text/uri-list`, `text/html`.
   - Limite de segurança: até 2 MiB.
   - Textos têm quebras de linha e caracteres contados, e recebem classificação semântica:
     - URL (`http://` ou `https://`): ícone `󰌷`
     - Código (`{`, `function`, `import `, `def `, `<`): ícone `󰘐`
     - Texto comum: ícone `󰅇`

---

## Deduplicação e Prevenção de Loops

Ao restaurar um item com `wl-copy`, o Wayland gera um novo evento de seleção. Para evitar loops infinitos e entradas duplicadas:
- O daemon calcula o `content_hash` canônico do item copiado.
- Se o item mais recente do banco já possuir esse mesmo `content_hash`, a captura é um no-op silencioso.
- Se o conteúdo copiado já existe em uma posição anterior do histórico, sua data de criação (`created_at`) é atualizada para o timestamp atual, promovendo-o ao topo do histórico sem criar registros duplicados nem replicar blobs em disco.
- Capturas concorrentes obtêm o bloqueio de escrita do SQLite antes de consultar o hash. O snapshot mostra uma entrada por hash mesmo se uma corrida antiga deixou duplicatas no banco; os registros antigos não são apagados automaticamente.

---

## Retenção e Limpeza de Histórico

- **Spotlight**: carrega e exibe até 200 itens recentes no modo clipboard (`#` ou `SUPER+C`).
- **Capacidade padrão**: 500 itens não fixados (`pinned = 0`).
- Ao ultrapassar 500 itens, os registros mais antigos não fixados são apagados automaticamente.
- Itens com `pinned = 1` são preservados permanentemente da limpeza automática.
- Ao excluir um item (manual ou via retenção), o arquivo em `blobs/` é removido se e somente se nenhum outro registro no banco ainda apontar para ele.

---

## Restauração (`clipboard-restore`)

Ao pressionar `Enter` (ou clicar duas vezes) sobre um item no Spotlight:
- O helper consulta o item pelo seu `id` permanente no SQLite.
- Se for imagem, envia os bytes do blob para `wl-copy --type <primary_mime>`.
- Se for texto, envia o conteúdo completo em UTF-8 para `wl-copy --type <primary_mime>`.
- O item é promovido para o topo do histórico.
- O Spotlight fecha imediatamente após a confirmação.

Links de texto contendo somente uma URL HTTP(S) também oferecem “Baixar vídeo”
e “Baixar áudio” no painel de ações (`Ctrl+K` ou botão “Ações” no rodapé).
O painel substitui temporariamente o preview; `Esc` retorna ao preview do item.
A detecção é local e não consulta
`yt-dlp` até a ação ser escolhida. `Enter` continua restaurando o link ao
clipboard; textos com URL acompanhada de conteúdo adicional não recebem ações
de download.

No modo Clipboard, `→` abre as ações do item selecionado e o rodapé indica esse
atalho.

---

## Remoção (`clipboard-remove`)

Ao pressionar `Shift+Delete` (ou clicar em `󰆴 Del` no cabeçalho do preview):
- O item é removido imediatamente da lista local na interface, proporcionando feedback visual com latência zero.
- O comando `clipboard-remove <id> <signature>` é enviado ao backend.
- O SQLite deleta a linha permanentemente e o arquivo blob correspondente é apagado caso não esteja em uso.
- O cache `clipboard-index.json` é sincronizado para evitar que o item reapareça em reinicializações da busca.

---

## Ciclo de Vida do Daemon

O daemon `clipboard-daemon.py` é gerenciado diretamente pelo Quickshell via `services/ClipboardService.qml` instanciado no `ShellRoot` de `shell.qml`:
- Inicia uma única vez por sessão do desktop (nunca por monitor).
- Escuta sinais `SIGTERM`, `SIGINT` e `SIGHUP` para encerrar o processo filho `wl-paste` de forma limpa.
- Se o `wl-paste` encerrar inesperadamente (por exemplo, durante reinício do compositor), o supervisor reinicia o monitor após 1 segundo.
- Um lockfile em `~/.local/share/quickshell/clipboard/daemon.lock` garante que apenas uma instância do daemon opere simultaneamente.

---

## Dependências

- **Python 3** (módulos da biblioteca padrão: `sqlite3`, `hashlib`, `json`, `subprocess`, `fcntl`, `signal`, `shutil`).
- **wl-clipboard** (`wl-paste` e `wl-copy`).

Se o `wl-clipboard` não estiver disponível no `PATH`, o backend retorna:
```json
{
  "available": false,
  "backend": "native",
  "error": "wl-clipboard não disponível",
  "items": []
}
```
e a interface exibe a mensagem de indisponibilidade de forma amigável.

---

## Troubleshooting

1. **Verificar status do clipboard**:
   ```bash
   python3 ~/.config/quickshell/scripts/clipboard-daemon.py --status
   ```
2. **Testar captura pontual**:
   ```bash
   wl-copy "Teste manual"
   python3 ~/.config/quickshell/scripts/clipboard-daemon.py --capture
   ```
3. **Verificar processo em execução**:
   ```bash
   ps aux | grep clipboard-daemon
   ```
4. **Executar suite de testes unitários**:
   ```bash
   python3 -m unittest discover -s ~/.config/quickshell/tests -p "test_*.py"
   ```
