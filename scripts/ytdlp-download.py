#!/usr/bin/env python3
"""yt-dlp download backend with a versioned JSON contract for QML.

Subcommands (all print {"ok", "version", "data", "error"}):
  info <url>                  metadata only (--dump-single-json, no download)
  start <url> [--mode video|audio] [--quality ..] [--format ..] [--dest DIR]
                              spawn a detached yt-dlp, remember choices
  status <job_id>             progress / final state of one job
  cancel <job_id>             terminate a running job
  recent [--limit N]          newest jobs first (offline-safe)
  prefs [--set k=v ...]       remembered quality/format/dest (offline-safe)

No shell is ever used: URLs travel as single argv items. Bare invocation
prints prefs so scripts/validate.sh can probe it without network.
"""
import hashlib
import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True

VERSION = 1
YTDLP = "yt-dlp"
INFO_TIMEOUT = 30

VIDEO_QUALITIES = ["best", "1080p", "720p", "480p"]
VIDEO_FORMATS = ["mp4", "mkv"]
AUDIO_FORMATS = ["mp3", "m4a", "opus"]
DEFAULT_DEST = "~/Downloads"

URL_RE = re.compile(r"^https?://[^\s/$.?#].[^\s]*$", re.IGNORECASE)
PROGRESS_RE = re.compile(r"^YTDLP_PROGRESS\s+(.*?)\|(.*?)\|(.*)$")
FILE_MARKER = "YTDLP_FILE:"


def fail(message, data=None):
    return {"ok": False, "version": VERSION, "data": data or {},
            "error": message}


def succeed(data):
    return {"ok": True, "version": VERSION, "data": data, "error": None}


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(
        os.path.expanduser("~"), ".local", "state")
    return Path(base) / "quickshell" / "ytdlp"


def jobs_dir():
    return state_dir() / "jobs"


def prefs_path():
    return state_dir() / "prefs.json"


def default_prefs():
    return {"quality": "720p", "format": "mp4", "dest": DEFAULT_DEST}


def load_prefs():
    prefs = default_prefs()
    try:
        stored = json.loads(prefs_path().read_text(encoding="utf-8"))
        for key in prefs:
            if isinstance(stored.get(key), str) and stored[key].strip():
                prefs[key] = stored[key]
    except (OSError, ValueError):
        pass
    return prefs


def save_prefs(prefs):
    try:
        state_dir().mkdir(parents=True, exist_ok=True)
        prefs_path().write_text(json.dumps(prefs, ensure_ascii=False, indent=2),
                                encoding="utf-8")
    except OSError:
        pass


def validate_url(url):
    url = (url or "").strip()
    if not url:
        return "Link vazio."
    if len(url) > 2048:
        return "Link muito longo."
    if not URL_RE.match(url):
        return "Link inválido: use http(s)://…"
    return None


def validate_dest(dest):
    dest = os.path.expanduser((dest or "").strip())
    if not dest:
        return None, "Destino vazio."
    if not os.path.isabs(dest):
        return None, "Destino precisa ser absoluto."
    if "\n" in dest or "\0" in dest:
        return None, "Destino inválido."
    return dest, None


def validate_thumbnail_url(url):
    url = (url or "").strip()
    if not url:
        return "", None
    if len(url) > 4096 or not URL_RE.match(url):
        return None, "URL da miniatura inválida."
    return url, None


def run_ytdlp(args, timeout):
    try:
        proc = subprocess.run([YTDLP] + args, capture_output=True, text=True,
                              timeout=timeout)
    except FileNotFoundError:
        return None, "yt-dlp não instalado."
    except subprocess.TimeoutExpired:
        return None, "Tempo limite excedido."
    except OSError as exc:
        return None, str(exc)
    return proc, None


def pick_thumbnail(info):
    thumbs = info.get("thumbnails") or []
    if isinstance(thumbs, list) and thumbs:
        with_url = [t for t in thumbs if isinstance(t, dict) and t.get("url")]
        if with_url:
            # Quickshell's Qt image plugins on this host support JPEG, PNG,
            # GIF and ICO, but not WebP. Prefer a decodable thumbnail so the
            # preview does not emit a QQuickImage decode error.
            supported = [t for t in with_url
                         if str(t.get("ext") or "").lower() in
                         ("jpg", "jpeg", "png", "gif", "ico")]
            if supported:
                return str(supported[-1]["url"])
            unknown_format = [t for t in with_url if not t.get("ext")]
            if unknown_format:
                return str(unknown_format[-1]["url"])
    for key in ("thumbnail",):
        if info.get(key) and str(info[key]).lower().split("?", 1)[0].endswith(
                (".jpg", ".jpeg", ".png", ".gif", ".ico")):
            return str(info[key])
    return ""


def available_heights(info):
    heights = set()
    for fmt in info.get("formats") or []:
        if not isinstance(fmt, dict):
            continue
        height = fmt.get("height")
        vcodec = str(fmt.get("vcodec") or "")
        if isinstance(height, int) and vcodec != "none":
            heights.add(height)
    return sorted(heights, reverse=True)


def format_duration(seconds):
    try:
        total = int(seconds)
    except (TypeError, ValueError):
        return ""
    if total < 0:
        return ""
    hours, rest = divmod(total, 3600)
    minutes, secs = divmod(rest, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def cmd_info(url):
    err = validate_url(url)
    if err:
        return fail(err)
    context = {"url": url.strip()}
    proc, proc_err = run_ytdlp(["--dump-single-json", "--no-download",
                                "--no-playlist", "--no-warnings", url],
                               timeout=INFO_TIMEOUT)
    if proc_err:
        return fail(proc_err, context)
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip().splitlines()
        return fail(detail[-1] if detail else "yt-dlp não reconheceu o link.",
                    context)
    try:
        info = json.loads(proc.stdout)
    except ValueError:
        return fail("Resposta inválida do yt-dlp.", context)
    if not isinstance(info, dict):
        return fail("Resposta inválida do yt-dlp.", context)
    return succeed({
        "id": str(info.get("id") or ""),
        "title": str(info.get("title") or url),
        "duration": info.get("duration"),
        "duration_str": format_duration(info.get("duration")),
        "thumbnail": pick_thumbnail(info),
        "is_live": bool(info.get("is_live")),
        "ext": str(info.get("ext") or ""),
        "qualities": VIDEO_QUALITIES,
        "video_formats": VIDEO_FORMATS,
        "audio_formats": AUDIO_FORMATS,
        "heights": available_heights(info),
        "url": url.strip(),
    })


def build_format_args(mode, quality, fmt):
    if mode == "audio":
        if fmt not in AUDIO_FORMATS:
            return None, f"Formato de áudio inválido: {fmt}."
        return ["-x", "--audio-format", fmt, "--audio-quality", "0"], None
    if quality not in VIDEO_QUALITIES:
        return None, f"Qualidade inválida: {quality}."
    if fmt not in VIDEO_FORMATS:
        return None, f"Formato de vídeo inválido: {fmt}."
    if quality == "best":
        selector = "bv*+ba/b"
    else:
        height = quality.rstrip("p")
        selector = f"bv*[height<={height}]+ba/b[height<={height}]/b"
    return ["-f", selector, "--remux-video", fmt], None


def cmd_start(url, mode="video", quality=None, fmt=None, dest=None,
              thumbnail=None):
    err = validate_url(url)
    if err:
        return fail(err)
    prefs = load_prefs()
    mode = (mode or "video").strip().lower()
    if mode not in ("video", "audio"):
        return fail(f"Modo inválido: {mode}.")
    quality = (quality or prefs["quality"]).strip()
    fmt = (fmt or (prefs["format"] if mode == "video" else "mp3")).strip()
    dest, dest_err = validate_dest(dest or prefs["dest"])
    if dest_err:
        return fail(dest_err)
    thumbnail, thumbnail_err = validate_thumbnail_url(thumbnail)
    if thumbnail_err:
        return fail(thumbnail_err)
    format_args, format_err = build_format_args(mode, quality, fmt)
    if format_err:
        return fail(format_err)
    try:
        os.makedirs(dest, exist_ok=True)
    except OSError as exc:
        return fail(f"Não foi possível criar o destino: {exc}")
    job_id = time.strftime("%Y%m%d-%H%M%S") + "-" + hashlib.sha1(
        url.encode("utf-8")).hexdigest()[:8]
    job_dir = jobs_dir() / job_id
    try:
        job_dir.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        return fail(f"Não foi possível criar o estado: {exc}")
    log_path = job_dir / "download.log"
    argv = [YTDLP, "--no-playlist", "--newline",
            "--progress-template", "YTDLP_PROGRESS %(progress._percent_str)s|%(progress._eta_str)s|%(progress._speed_str)s",
            "--print", "after_move:YTDLP_FILE:%(filepath)s",
            "-o", os.path.join(dest, "%(title)s [%(id)s].%(ext)s")] \
        + format_args + [url.strip()]
    try:
        with open(log_path, "w", encoding="utf-8") as log:
            proc = subprocess.Popen(argv, stdout=log, stderr=subprocess.STDOUT,
                                    start_new_session=True)
    except FileNotFoundError:
        return fail("yt-dlp não instalado.")
    except OSError as exc:
        return fail(str(exc))
    job = {"job_id": job_id, "url": url.strip(), "mode": mode,
           "quality": quality, "format": fmt, "dest": dest,
           "thumbnail": thumbnail,
           "pid": proc.pid, "status": "running",
           "created_at": time.time(), "argv_preview": ["yt-dlp", "..."]}
    try:
        (job_dir / "job.json").write_text(json.dumps(job, ensure_ascii=False),
                                          encoding="utf-8")
    except OSError as exc:
        return fail(f"Não foi possível registrar o job: {exc}")
    prefs.update({"quality": quality, "format": fmt, "dest": dest})
    save_prefs(prefs)
    return succeed({"job_id": job_id, "log": str(log_path), "dest": dest})


def read_job(job_id):
    job_path = jobs_dir() / job_id / "job.json"
    try:
        job = json.loads(job_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return job if isinstance(job, dict) else None


def pid_alive(pid):
    try:
        os.kill(int(pid), 0)
        return True
    except (OSError, ValueError, TypeError):
        return False


def parse_log(log_path):
    percent = eta = speed = ""
    final_file = ""
    try:
        lines = Path(log_path).read_text(encoding="utf-8",
                                         errors="replace").splitlines()
    except OSError:
        return percent, eta, speed, final_file
    for line in lines:
        if line.startswith(FILE_MARKER):
            candidate = line[len(FILE_MARKER):].strip()
            if candidate:
                final_file = candidate
            continue
        match = PROGRESS_RE.match(line.strip())
        if match:
            percent, eta, speed = (part.strip() for part in match.groups())
    return percent, eta, speed, final_file


def job_status(job):
    if job.get("status") == "cancelled":
        return "cancelled"
    log_path = jobs_dir() / job["job_id"] / "download.log"
    percent, eta, speed, final_file = parse_log(log_path)
    if final_file and os.path.exists(final_file):
        return {"status": "done", "percent": "100%", "eta": "",
                "speed": "", "file": final_file}
    if pid_alive(job.get("pid")):
        return {"status": "running", "percent": percent, "eta": eta,
                "speed": speed, "file": ""}
    if final_file:
        return {"status": "error", "percent": percent, "eta": "",
                "speed": "", "file": "",
                "error": "Processo terminou sem o arquivo final."}
    return {"status": "error", "percent": percent, "eta": "", "speed": "",
            "file": "", "error": "Download falhou; veja o log."}


def cmd_status(job_id):
    job = read_job((job_id or "").strip())
    if not job:
        return fail("Job desconhecido.")
    state = job_status(job)
    if isinstance(state, str):
        return succeed({"job_id": job["job_id"], "status": state,
                        "title": job.get("title", ""), "url": job.get("url", ""),
                        "mode": job.get("mode", ""), "file": ""})
    if state["status"] == "done" and not job.get("title"):
        job["title"] = os.path.basename(state["file"])
        try:
            (jobs_dir() / job["job_id"] / "job.json").write_text(
                json.dumps(job, ensure_ascii=False), encoding="utf-8")
        except OSError:
            pass
    payload = {"job_id": job["job_id"], "title": job.get("title", ""),
               "url": job.get("url", ""), "mode": job.get("mode", "")}
    payload.update(state)
    return succeed(payload)


def cmd_cancel(job_id):
    job = read_job((job_id or "").strip())
    if not job:
        return fail("Job desconhecido.")
    pid = job.get("pid")
    if pid_alive(pid):
        try:
            os.kill(int(pid), signal.SIGTERM)
        except (OSError, ValueError, TypeError) as exc:
            return fail(f"Não foi possível cancelar: {exc}")
    job["status"] = "cancelled"
    try:
        (jobs_dir() / job["job_id"] / "job.json").write_text(
            json.dumps(job, ensure_ascii=False), encoding="utf-8")
    except OSError as exc:
        return fail(str(exc))
    return succeed({"job_id": job["job_id"], "status": "cancelled"})


def cmd_recent(limit=10):
    try:
        limit = max(1, min(50, int(limit)))
    except (TypeError, ValueError):
        limit = 10
    entries = []
    base = jobs_dir()
    if base.is_dir():
        for child in base.iterdir():
            job = read_job(child.name)
            if job:
                state = job_status(job)
                status = state if isinstance(state, str) else state["status"]
                entries.append({
                    "job_id": job["job_id"],
                    "title": job.get("title") or job.get("url", ""),
                    "url": job.get("url", ""),
                    "mode": job.get("mode", ""),
                    "status": status,
                    "dest": job.get("dest", ""),
                    "thumbnail": job.get("thumbnail", ""),
                    "file": "" if isinstance(state, str) else state.get("file", ""),
                    "created_at": job.get("created_at", 0),
                })
    entries.sort(key=lambda e: e["created_at"], reverse=True)
    return succeed({"jobs": entries[:limit]})


def cmd_prefs(overrides):
    prefs = load_prefs()
    for item in overrides:
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        key, value = key.strip(), value.strip()
        if key in prefs and value:
            prefs[key] = value
    if overrides:
        save_prefs(prefs)
    return succeed({"prefs": prefs, "video_qualities": VIDEO_QUALITIES,
                    "video_formats": VIDEO_FORMATS,
                    "audio_formats": AUDIO_FORMATS})


def main(argv):
    if not argv or argv[0] in ("prefs",):
        rest = argv[1:] if argv else []
        if rest and rest[0] == "--set":
            return cmd_prefs(rest[1:])
        return cmd_prefs([])
    command, rest = argv[0], argv[1:]
    if command == "info":
        if not rest:
            return fail("Uso: info <url>.")
        return cmd_info(rest[0])
    if command == "start":
        if not rest:
            return fail("Uso: start <url> [--mode ..] [--quality ..] [--format ..] [--dest ..].")
        opts = {"mode": "video", "quality": None, "fmt": None,
                "dest": None, "thumbnail": None}
        key = None
        for token in rest[1:]:
            if token.startswith("--"):
                key = "fmt" if token == "--format" else token[2:]
                if key not in opts:
                    return fail(f"Opção desconhecida: {token}.")
                opts[key] = ""
            elif key is None:
                return fail(f"Opção desconhecida: {token}.")
            else:
                opts[key] = token
                key = None
        return cmd_start(rest[0], **opts)
    if command == "status":
        if not rest:
            return fail("Uso: status <job_id>.")
        return cmd_status(rest[0])
    if command == "cancel":
        if not rest:
            return fail("Uso: cancel <job_id>.")
        return cmd_cancel(rest[0])
    if command == "recent":
        limit = 10
        if "--limit" in rest:
            try:
                limit = int(rest[rest.index("--limit") + 1])
            except (IndexError, ValueError):
                return fail("Uso: recent [--limit N].")
        return cmd_recent(limit)
    return fail(f"Comando desconhecido: {command}.")


if __name__ == "__main__":
    try:
        response = main(sys.argv[1:])
    except Exception as exc:
        response = fail(f"Erro interno no helper yt-dlp: {exc}")
    print(json.dumps(response, ensure_ascii=False, indent=2))
