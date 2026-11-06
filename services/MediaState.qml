pragma ComponentBehavior: Bound

pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

QtObject {
    id: root

    readonly property var rawPlayers: Mpris.players.values

    function metadataArtist(p) {
        if (!p) return ""

        const direct = String(p.trackArtist ?? "").trim()
        if (direct.length > 0)
            return direct

        const albumArtist = String(p.trackAlbumArtist ?? "").trim()
        if (albumArtist.length > 0)
            return albumArtist

        try {
            const raw = p.metadata ? p.metadata["xesam:artist"] : null

            if (raw !== null && raw !== undefined) {
                if (Array.isArray(raw))
                    return raw.map(x => String(x).trim())
                              .filter(x => x.length > 0)
                              .join(", ")

                if (typeof raw === "object" && raw.length !== undefined) {
                    const parts = []
                    for (let i = 0; i < raw.length; i++) {
                        const value = String(raw[i] ?? "").trim()
                        if (value.length > 0)
                            parts.push(value)
                    }
                    if (parts.length > 0)
                        return parts.join(", ")
                }

                const value = String(raw).trim()
                if (value.length > 0 && value !== "undefined" && value !== "null")
                    return value
            }
        } catch (e) {
        }

        return ""
    }

    function displayArtist(p) {
        const value = metadataArtist(p)
        return value.length > 0 ? value : "Artista desconhecido"
    }

    function dedupedPlayers() {
        const seen = {}
        const result = []
        // Mpris.players is an UntypedObjectModel; values is exposed at runtime.
        // qmllint disable missing-property
        const raw = Mpris.players.values
        // qmllint enable missing-property

        for (let i = 0; i < raw.length; i++) {
            const p = raw[i]
            if (!p) continue

            const key =
                String(p.identity ?? "") + "\x1f" +
                String(p.trackTitle ?? "") + "\x1f" +
                metadataArtist(p)

            if (!seen[key]) {
                seen[key] = true
                result.push(p)
            }
        }

        return result
    }

    property var _playersCache: []
    readonly property var players: _playersCache

    // Manual selection is shared by Quick Settings, the media popup, and shortcuts.
    property var selectedPlayer: null
    property string selectedPlayerKey: ""
    property var player: null
    property bool _resolvePending: false

    function playerKey(p) {
        if (!p) return ""
        return String(p.dbusName || p.identity || "")
    }

    function selectPlayer(p) {
        if (!p) return
        const key = playerKey(p)
        const available = dedupedPlayers().find(candidate => candidate === p || (
            key.length > 0 && playerKey(candidate) === key
        ))
        if (!available) return
        selectedPlayer = available
        selectedPlayerKey = playerKey(available)
        player = available
    }

    property IpcHandler ipc: IpcHandler {
        target: "media"

        function togglePlayback(): void {
            root.togglePlayback()
        }
    }

    function togglePlayback() {
        if (!player)
            resolvePlayer()

        if (player)
            player.togglePlaying()
    }

    onSelectedPlayerChanged: {
        selectedPlayerKey = playerKey(selectedPlayer)
        queueResolve()
    }

    function queueResolve() {
        if (_resolvePending) return
        _resolvePending = true
        Qt.callLater(() => {
            _resolvePending = false
            resolvePlayer()
        })
    }

    function resolvePlayer() {
        const list = dedupedPlayers()
        _playersCache = list

        let chosen = null

        // Preserve a manual choice even if Qt recreates its MPRIS proxy object.
        const manualSelection = list.find(p => p && (
            p === selectedPlayer ||
            (selectedPlayerKey.length > 0 && playerKey(p) === selectedPlayerKey)
        ))

        if (manualSelection) {
            chosen = manualSelection
            selectedPlayer = manualSelection
            selectedPlayerKey = playerKey(manualSelection)
        } else {
            selectedPlayer = null
            selectedPlayerKey = ""
            // 2. Active player currently playing WITH a title
            const playingWithTitle = list.find(p => p && p.isPlaying && String(p.trackTitle ?? "").trim().length > 0)
            if (playingWithTitle) {
                chosen = playingWithTitle
            } else {
                // 3. Any active player currently playing
                const playing = list.find(p => p && p.isPlaying)
                if (playing) {
                    chosen = playing
                } else if (player && list.indexOf(player) >= 0 && String(player.trackTitle ?? "").trim().length > 0) {
                    // 4. Preserve current player if it still exists and has a track title (e.g. paused music)
                    chosen = player
                } else {
                    // 5. Any player that currently has a track title (e.g. Spotify paused)
                    const withTitle = list.find(p => p && String(p.trackTitle ?? "").trim().length > 0)
                    if (withTitle) {
                        chosen = withTitle
                    } else {
                        // 6. Fallback: first available player or null
                        chosen = list.length > 0 ? list[0] : null
                    }
                }
            }
        }

        player = chosen
    }

    // Reactively watch all MPRIS players for playback and metadata events
    property var _watcher: Instantiator {
        model: Mpris.players
        delegate: Item {
            id: playerWatcherDelegate
            visible: false
            required property var modelData

            Connections {
                target: playerWatcherDelegate.modelData
                function onIsPlayingChanged() { root.queueResolve() }
                function onTrackTitleChanged() { root.queueResolve() }
                function onPlaybackStateChanged() { root.queueResolve() }
                function onMetadataChanged() { root.queueResolve() }
            }

            Component.onCompleted: root.queueResolve()
            Component.onDestruction: root.queueResolve()
        }
    }

    Component.onCompleted: resolvePlayer()
}
