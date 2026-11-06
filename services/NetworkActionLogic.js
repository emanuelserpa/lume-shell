.pragma library

function vpnSetArguments(uuid, enabled) {
    return ["vpn-set", String(uuid), enabled ? "on" : "off"]
}
