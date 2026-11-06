#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


class WifiQrError(Exception):
    """An actionable failure while reading the active Wi-Fi profile."""


def parse_nmcli_terse_line(line):
    """Split one nmcli terse row, honoring its backslash-escaped separators."""
    fields = []
    field = []
    escaped = False
    for char in line:
        if escaped:
            field.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append("".join(field))
            field = []
        else:
            field.append(char)
    if escaped:
        field.append("\\")
    fields.append("".join(field))
    return fields


def escape_wifi_qr_field(value):
    """Escape reserved characters in the ZXing Wi-Fi QR payload format."""
    reserved = {"\\", ";", ",", ":", '"'}
    return "".join(("\\" + char) if char in reserved else char for char in value)


def nmcli_query(*args, show_secrets=False):
    command = ["nmcli", "-t", "--escape", "yes"]
    if show_secrets:
        command.append("--show-secrets")
    command.extend(args)
    try:
        proc = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except subprocess.TimeoutExpired as exc:
        raise WifiQrError("A consulta da rede Wi-Fi expirou.") from exc
    except OSError as exc:
        raise WifiQrError("Não foi possível consultar o NetworkManager.") from exc

    if proc.returncode != 0:
        raise WifiQrError("Não foi possível ler os dados da rede Wi-Fi ativa.")
    return proc.stdout


def active_wifi_profile():
    output = nmcli_query(
        "-f", "UUID,TYPE", "connection", "show", "--active"
    )
    for line in output.splitlines():
        fields = parse_nmcli_terse_line(line)
        if len(fields) >= 2 and fields[1] == "802-11-wireless" and fields[0]:
            return fields[0]
    raise WifiQrError("Nenhuma rede Wi-Fi ativa.")


def connection_value(uuid, field, *, show_secrets=False):
    output = nmcli_query(
        "-g", field, "connection", "show", "uuid", uuid,
        show_secrets=show_secrets,
    )
    lines = output.splitlines()
    if len(lines) > 1:
        raise WifiQrError("O NetworkManager retornou dados inesperados para a rede.")
    return parse_nmcli_terse_line(lines[0])[0] if lines else ""


def wifi_qr_details():
    uuid = active_wifi_profile()
    ssid = connection_value(uuid, "802-11-wireless.ssid")
    if not ssid:
        raise WifiQrError("Não foi possível identificar o SSID da rede Wi-Fi ativa.")

    psk = connection_value(
        uuid,
        "802-11-wireless-security.psk",
        show_secrets=True,
    )
    if psk:
        security = "WPA"
    else:
        key_mgmt = connection_value(uuid, "802-11-wireless-security.key-mgmt")
        if key_mgmt == "none":
            psk = connection_value(
                uuid,
                "802-11-wireless-security.wep-key0",
                show_secrets=True,
            )
            if not psk:
                raise WifiQrError("A chave WEP da rede ativa não está disponível.")
            security = "WEP"
        elif key_mgmt == "":
            security = "nopass"
        else:
            raise WifiQrError(
                "Esta rede usa um método de autenticação que não pode ser compartilhado por QR."
            )

    payload = (
        f"WIFI:T:{security};S:{escape_wifi_qr_field(ssid)};"
        f"P:{escape_wifi_qr_field(psk)};;"
    )
    return ssid, psk, payload


def result(ok, action, error=None, detail=""):
    print(json.dumps({
        "ok": bool(ok),
        "action": action,
        "error": error or None,
        "detail": detail,
    }, ensure_ascii=False))
    return 0 if ok else 1


def friendly_error(stderr, stdout=""):
    raw = (stderr or stdout or "").strip()
    low = raw.lower()

    if not raw:
        return "A operação de rede falhou."

    if "secrets were required" in low or "no secrets" in low:
        return "A credencial necessária não foi fornecida."
    if "activation failed" in low and ("password" in low or "secret" in low):
        return "Não foi possível autenticar. Verifique a senha."
    if "wrong password" in low or "bad password" in low:
        return "Senha incorreta."
    if "no network with ssid" in low or "not found" in low:
        return "A rede não está mais disponível."
    if "connection activation failed" in low:
        return "Não foi possível ativar a conexão."
    if "device" in low and "disconnected" in low:
        return "O dispositivo de rede está desconectado."
    if "not authorized" in low or "permission" in low:
        return "Sem permissão para executar esta operação."
    if "timeout" in low or "timed out" in low:
        return "A operação de rede expirou."

    # Keep the popup useful without dumping a giant nmcli message.
    first = raw.splitlines()[0].strip()
    return first[:180]


def run_nmcli(action, args, input_data=None):
    try:
        p = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            input=input_data,
            timeout=40,
        )
    except subprocess.TimeoutExpired:
        return result(False, action, "A operação de rede expirou.")
    except Exception as e:
        return result(False, action, "Não foi possível executar o NetworkManager.", str(e))

    if p.returncode == 0:
        return result(True, action)

    low = p.stderr.lower()
    if action == "vpn-up" and ("already activated" in low or "already active" in low):
        return result(True, action)
    if action == "vpn-down" and any(message in low for message in (
        "not an active connection", "is not active", "not active"
    )):
        return result(True, action)

    return result(False, action, friendly_error(p.stderr, p.stdout), p.stderr.strip())


def vpn_nmcli_command(uuid, enabled):
    operation = "up" if enabled else "down"
    return ["nmcli", "connection", operation, "uuid", uuid]


def saved_profile_key_mgmt(uuid):
    """Key management of a saved profile, "" when unknown or open."""
    try:
        return (connection_value(uuid, "802-11-wireless-security.key-mgmt") or "").strip()
    except WifiQrError:
        return ""


def connect_with_password(action, ssid, uuid, password):
    """Connect using a typed password, refreshing a saved profile when given.

    nmcli reuses the stored secret of an existing profile, so typing a new
    password would fail again with the stale one. Clear it first (an empty
    value carries no secret), then `nmcli --ask connection up` prompts for
    the new one over stdin. The password itself never touches argv.
    """
    if uuid and saved_profile_key_mgmt(uuid) not in ("", "none"):
        cleared = run_nmcli(action, ["nmcli", "connection", "modify", uuid, "wifi-sec.psk", ""])
        if cleared != 0:
            return cleared
        return run_nmcli(
            action,
            ["nmcli", "--ask", "connection", "up", "uuid", uuid],
            input_data=password + "\n",
        )
    return run_nmcli(
        action,
        ["nmcli", "--ask", "device", "wifi", "connect", ssid],
        input_data=password + "\n",
    )


def spawn(action, commands):
    for cmd in commands:
        try:
            subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            return result(True, action)
        except Exception:
            pass
    return result(False, action, "Não foi possível abrir o aplicativo solicitado.")


def main():
    if len(sys.argv) < 2:
        return result(False, "", "Ação de rede inválida.")

    action = sys.argv[1]

    if action == "wifi-on":
        return run_nmcli(action, ["nmcli", "radio", "wifi", "on"])

    if action == "wifi-off":
        return run_nmcli(action, ["nmcli", "radio", "wifi", "off"])

    if action == "disconnect":
        if len(sys.argv) < 3 or not sys.argv[2]:
            return result(False, action, "Dispositivo Wi‑Fi desconhecido.")
        return run_nmcli(action, ["nmcli", "device", "disconnect", sys.argv[2]])

    if action == "connect-saved":
        if len(sys.argv) < 3:
            return result(False, action, "Perfil de conexão inválido.")
        return run_nmcli(action, ["nmcli", "connection", "up", "uuid", sys.argv[2]])

    if action == "connect-open":
        if len(sys.argv) < 3:
            return result(False, action, "SSID inválida.")
        return run_nmcli(action, ["nmcli", "device", "wifi", "connect", sys.argv[2]])

    if action == "connect-password":
        if len(sys.argv) < 3:
            return result(False, action, "SSID ou senha inválidos.")
        ssid = sys.argv[2]
        uuid = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else ""
        password = sys.stdin.readline().removesuffix("\n")
        if not password:
            return result(False, action, "SSID ou senha inválidos.")
        return connect_with_password(action, ssid, uuid, password)

    if action == "wifi-qr":
        try:
            ssid, psk, payload = wifi_qr_details()
        except WifiQrError as exc:
            return result(False, action, str(exc))
        try:
            p = subprocess.run(
                ["qrencode", "-s", "6", "-m", "2", "-t", "PNG", "-o", "-"],
                input=payload.encode("utf-8"),
                capture_output=True,
                timeout=10,
            )
        except subprocess.TimeoutExpired:
            return result(False, action, "A geração do QR code expirou.")
        except OSError:
            return result(False, action, "Não foi possível executar o qrencode.")
        if p.returncode == 0:
            try:
                runtime_dir = Path(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir())
                private_dir = runtime_dir / f"quickshell-{os.getuid()}"
                private_dir.mkdir(mode=0o700, exist_ok=True)
                if private_dir.stat().st_uid != os.getuid():
                    raise OSError("private runtime directory has another owner")
                private_dir.chmod(0o700)
                out_path = private_dir / "wifi-qr.png"
                flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW
                fd = os.open(out_path, flags, 0o600)
                with os.fdopen(fd, "wb") as image_file:
                    os.fchmod(image_file.fileno(), 0o600)
                    image_file.write(p.stdout)
            except OSError:
                return result(False, action, "Não foi possível salvar o QR code.")
            print(json.dumps({
                "ok": True,
                "action": action,
                "path": str(out_path),
                "ssid": ssid,
                "password": psk
            }, ensure_ascii=False))
            return 0
        return result(False, action, "Não foi possível gerar o QR code.")

    if action == "copy":
        text = sys.stdin.readline().removesuffix("\n")
        if not text:
            return result(False, action, "Nenhum texto para copiar.")
        try:
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, text=True)
            p.communicate(input=text)
            return result(True, action)
        except Exception as e:
            return result(False, action, "Falha ao copiar para a área de transferência.", str(e))

    if action == "open-portal":
        return spawn(action, [
            ["xdg-open", "http://ping.archlinux.org/nm-check.txt"],
            ["xdg-open", "http://captive.apple.com"],
        ])

    if action == "editor":
        return spawn(action, [
            ["uwsm", "app", "--", "nm-connection-editor"],
            ["nm-connection-editor"],
        ])

    if action == "vpn-up":
        if len(sys.argv) < 3:
            return result(False, action, "Perfil VPN inválido.")
        return run_nmcli(action, ["nmcli", "connection", "up", "uuid", sys.argv[2]])

    if action == "vpn-down":
        if len(sys.argv) < 3:
            return result(False, action, "Perfil VPN inválido.")
        return run_nmcli(action, ["nmcli", "connection", "down", "uuid", sys.argv[2]])

    if action == "vpn-set":
        if len(sys.argv) < 4 or sys.argv[3] not in ("on", "off"):
            return result(False, action, "Estado de VPN inválido.")
        action_name = "vpn-up" if sys.argv[3] == "on" else "vpn-down"
        return run_nmcli(action_name, vpn_nmcli_command(sys.argv[2], sys.argv[3] == "on"))

    return result(False, action, "Ação de rede desconhecida.")


if __name__ == "__main__":
    raise SystemExit(main())
