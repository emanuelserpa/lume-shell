# yt-dlp Downloads via Spotlight

Paste a video link in Spotlight → `Baixar vídeo…` / `Baixar áudio…` →
small panel (title, thumbnail, duration, quality, format, destination) →
confirm. The download survives closing Spotlight; a notification fires on
completion. Type `downloads` to review recent jobs (open folder, retry,
cancel).

## Flow

1. `SpotlightQueryRouter` matches `https?://…` locally (no process while
   typing) and yields a `url` result; `downloads` lists recent jobs. A clipboard
   item containing only one HTTP(S) URL exposes the same download actions in
   its `Ctrl+K` panel.
2. `SpotlightActionCatalog` declares `download-video` and `download-audio`.
   For a typed URL, video download remains the primary Enter action. In clipboard
   history, restore remains primary and download actions are explicit choices.
   `SpotlightActionLogic.js` resolves download choices to
   `open-download-panel`.
3. `launcher/DownloadPanel.qml` fetches metadata lazily (`info`), offers
   quality/format/destination, and starts the job. Last choices persist in
   helper prefs; default destination is `~/Downloads`.
4. `services/DownloadState.qml` polls `recent` every 5 s only while a job
   is active and posts completion/failure via
   `NotificationState.postInternalNotification`, including the preview
   thumbnail on the completion/failure toast. The first poll after (re)start
   only baselines so old jobs never re-notify.

## Backend contract

`scripts/ytdlp-download.py info|start|status|cancel|recent|prefs` prints
`{"ok", "version": 1, "data": {...}, "error": ...}`. URLs travel as single
argv items; no shell is used. Job state lives under
`$XDG_STATE_HOME/quickshell/ytdlp/jobs/<id>/` (`job.json`, `download.log`).
Unexpected helper exceptions are returned through that JSON envelope so the
panel can show a useful failure instead of a JSON parse error.

`start` spawns yt-dlp detached (`start_new_session`) with `--newline` and
a `YTDLP_PROGRESS …|…|…` template plus a `YTDLP_FILE:` marker; `status`
derives running/done/error/cancelled from PID liveness, the marker, and
file existence. A validated HTTP(S) thumbnail URL is stored with job metadata
and reused in its completion or failure notification.

## Limits (slice 1)

- Single links only; playlists rejected (`--no-playlist`).
- No subtitles, no authenticated sites.
- Destination cycles `~/Downloads`, `~/Vídeos`, `~/Música`.
- The preview only selects thumbnail formats supported by the installed Qt
  image plugins; when a site exposes only WebP, it omits the thumbnail rather
  than logging a decode error.
- Keyboard focus starts on “Confirmar download”, so Enter starts immediately;
  move up to change quality, format, or destination first.
- Completion notification has no action buttons yet.
