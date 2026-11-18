pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Wayland
import Quickshell
import qs.lockscreen
import qs.bar
import qs.components
import qs.services

// shared-ui-guard: allow — the lockscreen media-art tile is a secure-surface trigger for its MPRIS popup.
Item {
    id: root

    required property var auth
    required property var theme

    readonly property var weather: WeatherState.weatherData ?? ({})
    readonly property var player: MediaState.player
    readonly property var mediaPlayers: MediaState.players.filter(player =>
        player && (player.isPlaying || String(player.trackTitle ?? "").trim().length > 0)
    )
    readonly property string trackTitle: String(player?.trackTitle ?? "").trim()
    readonly property string trackArtist: player ? MediaState.displayArtist(player) : ""
    readonly property string artworkUrl: String(player?.trackArtUrl ?? "").trim()
    readonly property real trackLength: Number(player?.length ?? 0)
    readonly property real trackPosition: Number(player?.position ?? 0)
    readonly property real trackProgress: trackLength > 0
        ? Math.max(0, Math.min(1, trackPosition / trackLength)) : 0

    function weatherIcon(glyph) {
        const icons = {
            "󰖙": "bar-sun", "󰖔": "bar-moon", "󰖕": "bar-cloud-sun",
            "󰖐": "bar-cloud", "󰖖": "bar-rain", "󰖗": "bar-rain",
            "󰙾": "bar-storm", "󰖘": "bar-snow", "󰖑": "bar-fog"
        }
        return icons[String(glyph ?? "")] ?? "bar-cloud"
    }

    function updatePlayerPosition() {
        if (root.player && root.player.isPlaying)
            root.player.positionChanged()
    }

    function activateFingerprint() {
        root.auth.requestFingerprintAuthentication()
    }

    anchors.fill: parent

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 20000
        repeat: true
        running: root.auth.sessionLock.secure
        onTriggered: {
            clock.enabled = false
            clock.enabled = true
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: Boolean(root.player?.isPlaying)
        onTriggered: root.updatePlayerPosition()
    }

    Rectangle {
        anchors.fill: parent
        color: root.theme.backgroundOpaque

        Image {
            anchors.fill: parent
            source: "file://" + ShellPaths.currentWallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        Rectangle {
            anchors.fill: parent
            color: root.theme.withAlpha(root.theme.backgroundOpaque, 0.30)
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: root.theme.withAlpha(root.theme.backgroundOpaque, 0.0)
                }
                GradientStop {
                    position: 0.45
                    color: root.theme.withAlpha(root.theme.backgroundOpaque, 0.14)
                }
                GradientStop {
                    position: 1.0
                    color: root.theme.withAlpha(root.theme.backgroundOpaque, 0.68)
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.20
            width: Math.min(720, parent.width * 0.76)
            spacing: 10

            Text {
                width: parent.width
                text: Qt.locale("pt_BR").toString(clock.date, "dddd, d 'de' MMMM")
                color: root.theme.foreground
                font.family: "Noto Sans"
                font.pixelSize: Math.max(16, root.theme.typeTokens.heading)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.theme.foreground
                font.family: "Noto Sans"
                font.pixelSize: Math.min(112, root.height * 0.125)
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideNone
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                TablerIcon {
                    width: 32
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: root.weatherIcon(root.weather.icon)
                    iconColor: root.theme.yellow
                }

                Text {
                    width: Math.min(460, implicitWidth)
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(root.weather.temperature ?? "--") + "°C  ·  "
                          + String(root.weather.description ?? "Previsão indisponível")
                    color: root.theme.offWhite
                    font.family: root.theme.fontFamily
                    font.pixelSize: Math.max(19, root.theme.typeTokens.heading + 3)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        LockscreenIsland {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 34
            anchors.rightMargin: 40
            theme: root.theme
        }

        Rectangle {
            id: mediaCard
            visible: root.player !== null && root.trackTitle.length > 0
            width: Math.min(552, parent.width * 0.42)
            height: Math.min(196, parent.height * 0.22)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: parent.height * 0.16
            radius: root.theme.radiusPopup
            color: root.theme.withAlpha(root.theme.surfaceContainerLow, 0.86)
            border.width: 1
            border.color: root.theme.withAlpha(root.theme.outline, 0.42)

            Row {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 20

                Rectangle {
                    id: mediaPopupTarget
                    width: Math.min(144, parent.height - 32)
                    height: width
                    radius: root.theme.radiusLg
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.theme.surface
                    clip: true

                    Image {
                        id: cover
                        anchors.fill: parent
                        source: root.artworkUrl
                        sourceSize.width: 288
                        sourceSize.height: 288
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: root.artworkUrl.length > 0 && status === Image.Ready
                    }

                    TablerIcon {
                        anchors.centerIn: parent
                        width: 38
                        height: 38
                        iconName: "bar-music"
                        iconColor: root.theme.accent
                        visible: !cover.visible
                    }

                    HoverHandler {
                        id: mediaPopupHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.theme.radiusLg
                        visible: mediaPopupHover.hovered
                        color: root.theme.withAlpha(root.theme.backgroundOpaque, 0.42)

                        TablerIcon {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            iconName: "dashboard-arrow-down"
                            iconColor: root.theme.foreground
                        }
                    }

                    TapHandler {
                        onTapped: mediaPopup.visible = !mediaPopup.visible
                    }

                    Keys.onReturnPressed: mediaPopup.visible = !mediaPopup.visible
                    Keys.onSpacePressed: mediaPopup.visible = !mediaPopup.visible
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Abrir seletor de player de mídia"
                }

                Column {
                    width: parent.width - 164
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        width: parent.width
                        text: root.trackTitle
                        textFormat: Text.PlainText
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.titleLarge
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        width: parent.width
                        text: root.trackArtist
                        textFormat: Text.PlainText
                        color: root.theme.offWhite
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.title
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Rectangle {
                        width: parent.width
                        height: 5
                        radius: height / 2
                        color: root.theme.sliderTrack
                        clip: true

                        Rectangle {
                            width: parent.width * root.trackProgress
                            height: parent.height
                            radius: parent.radius
                            color: root.theme.accent
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 26

                        Repeater {
                            model: ["previous", "toggle", "next"]

                            delegate: Rectangle {
                                id: controlDelegate
                                required property string modelData
                                width: controlDelegate.modelData === "toggle" ? 42 : 34
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: controlDelegate.modelData === "toggle"
                                       ? root.theme.withAlpha(root.theme.accent, 0.38)
                                       : "transparent"

                                TablerIcon {
                                    anchors.centerIn: parent
                                    width: 21
                                    height: 21
                                    iconName: controlDelegate.modelData === "previous" ? "bar-prev"
                                              : controlDelegate.modelData === "next" ? "bar-next"
                                              : root.player?.isPlaying ? "bar-pause" : "bar-play"
                                    iconColor: root.theme.foreground
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!root.player)
                                            return
                                        if (controlDelegate.modelData === "previous")
                                            root.player.previous()
                                        else if (controlDelegate.modelData === "next")
                                            root.player.next()
                                        else
                                            root.player.togglePlaying()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: authPanel
            width: Math.min(root.width - 48, 380)
            height: authContent.implicitHeight + 32
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.max(40, parent.height * 0.06)
            radius: root.theme.radiusXl
            color: root.theme.glassPanelSurface
            border.width: 1
            border.color: root.theme.glassBorder

            Behavior on height {
                enabled: root.theme.qmlAnimationsEnabled
                NumberAnimation {
                    duration: root.theme.motionStandard
                    easing.type: root.theme.motionEasing
                }
            }

            Column {
                id: authContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Item {
                    id: fingerprintAction
                    width: parent.width
                    height: 44
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: root.auth.fingerprintActive
                                      ? "Leitor de impressão digital ativo"
                                      : "Tentar impressão digital novamente"

                    Rectangle {
                        anchors.fill: parent
                        radius: root.theme.radiusButton
                        color: fingerprintHover.hovered
                               ? root.theme.glassHoverSurface : "transparent"
                    }

                    Rectangle {
                        width: 36
                        height: 36
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 18
                        color: root.theme.glassActiveSurface

                        TablerIcon {
                            anchors.centerIn: parent
                            width: 19
                            height: 19
                            iconName: "bar-lock"
                            iconColor: root.theme.primary
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 48
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: "Impressão digital"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.title
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: root.auth.status.startsWith("Digital não reconhecida")
                                  || root.auth.status.startsWith("Leitor indisponível")
                                  || root.auth.status.startsWith("Erro na senha")
                                  ? root.auth.status
                                  : root.auth.fingerprintActive
                                    ? root.auth.passwordPromptVisible
                                      ? "Leitor ativo · pode digitar ao mesmo tempo"
                                      : "Leitor ativo · coloque o dedo quando quiser"
                                    : root.auth.status
                            color: root.theme.textMuted
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.subtitle
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler {
                        id: fingerprintHover
                        cursorShape: root.auth.fingerprintActive
                                      ? Qt.ArrowCursor : Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: !root.auth.fingerprintActive
                        onTapped: root.activateFingerprint()
                    }

                    Keys.onReturnPressed: root.activateFingerprint()
                    Keys.onSpacePressed: root.activateFingerprint()
                }

                Rectangle {
                    width: parent.width
                    height: root.auth.passwordPromptVisible ? 0 : 38
                    radius: height / 2
                    visible: height > 0
                    color: passwordModeHover.hovered
                           ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                    border.width: 1
                    border.color: root.theme.glassBorderSubtle

                    Text {
                        anchors.centerIn: parent
                        text: "Usar senha"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.subtitle
                        font.weight: Font.DemiBold
                    }

                    HoverHandler {
                        id: passwordModeHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: !root.auth.passwordPromptVisible
                        onTapped: root.auth.requestPasswordAuthentication()
                    }

                    Behavior on height {
                        enabled: root.theme.qmlAnimationsEnabled
                        NumberAnimation {
                            duration: root.theme.motionStandard
                            easing.type: root.theme.motionEasing
                        }
                    }
                }

                TextField {
                    id: passwordField
                    width: parent.width
                    height: root.auth.passwordPromptVisible ? 48 : 0
                    opacity: root.auth.passwordPromptVisible ? 1 : 0
                    clip: true
                    placeholderText: "Senha"
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData
                                      | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    passwordMaskDelay: 0
                    enabled: root.auth.passwordPromptVisible
                             && root.auth.sessionLock.secure
                             && root.auth.sessionLock.locked
                    selectByMouse: false
                    focus: root.auth.passwordPromptVisible
                           && root.auth.sessionLock.secure
                    onTextEdited: root.auth.passwordPromptVisible = true
                    onAccepted: root.auth.submitPassword(text)

                    Behavior on height {
                        enabled: root.theme.qmlAnimationsEnabled
                        NumberAnimation {
                            duration: root.theme.motionStandard
                            easing.type: root.theme.motionEasing
                        }
                    }

                    Behavior on opacity {
                        enabled: root.theme.qmlAnimationsEnabled
                        NumberAnimation { duration: root.theme.motionFast }
                    }

                    background: Rectangle {
                        radius: height / 2
                        color: root.theme.glassCardSurface
                        border.width: passwordField.activeFocus ? 1.5 : 1
                        border.color: passwordField.activeFocus
                                      ? root.theme.withAlpha(root.theme.primary, 0.72)
                                      : root.theme.glassBorderSubtle
                    }

                    color: root.theme.foreground
                    placeholderTextColor: root.theme.textMuted
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.heading
                    leftPadding: 18
                    rightPadding: 18
                }
            }
        }
    }

    Connections {
        target: root.auth
        function onClearInputRequested() {
            passwordField.clear()
            passwordField.forceActiveFocus()
        }
    }

    MediaPopup {
        id: mediaPopup
        theme: root.theme
        target: mediaPopupTarget
        player: root.player
        players: root.mediaPlayers
        onPlayerSelected: function(selected) { MediaState.selectPlayer(selected) }
        onVisibleChanged: {
            if (!root.mediaPopup.visible) passwordField.forceActiveFocus()
        }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}
