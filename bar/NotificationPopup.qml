pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import qs.components
import qs.controlcenter
import qs.services
import "../services/NotificationContent.js" as NotificationContent

PopupWindow {
    id: root

    required property var theme
    required property Item target

    readonly property real swipeRunway: 160
    property bool swipeDismissActive: false
    property var expandedNotificationGroups: []
    function toggleNotificationGroup(key) {
        const keys = root.expandedNotificationGroups.slice()
        const index = keys.indexOf(key)
        if (index === -1) keys.push(key)
        else keys.splice(index, 1)
        root.expandedNotificationGroups = keys
    }

    property bool recordingActive: ScreenRecordingState.recording
    property bool recordingHasAudio: ScreenRecordingState.hasAudio
    property string recordingElapsedText: ScreenRecordingState.elapsedText
    signal openRecordingDetailsRequested()
    signal stopRecordingRequested()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    property int brightness: 0
    property bool brightnessAvailable: false
    property bool brightnessChanging: false
    property bool sessionActionsActive: false
    readonly property var runningGames: gameState.result.data.games ?? []
    readonly property bool gameActive: Boolean(gameState.result.data.active)

    // Media bindings
    readonly property var currentMedia: MediaState.player
    readonly property string mediaTitle: currentMedia ? String(currentMedia.trackTitle ?? "").trim() : ""
    readonly property bool hasMedia: Boolean(currentMedia && mediaTitle.length > 0)

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    // Keep the combined quick controls and history panel inside a typical
    // laptop screen; the history itself scrolls when it has more content.
    readonly property real availableNotifHeight: NotificationState.count > 0
        ? Math.min(340, Math.max(80, notifListView.contentHeight))
        : 0

    implicitWidth: root.theme.popupWidths.large + root.swipeRunway
    implicitHeight: card.implicitHeight

    color: "transparent"
    surfaceFormat.opaque: false
    property bool popupOpen: false
    property string pendingDetailsTarget: ""
    visible: false
    grabFocus: true

    function toggle() {
        root.pendingDetailsTarget = ""
        if (root.popupOpen) {
            root.closePopup()
        } else {
            closeFade.stop()
            root.popupOpen = true
            root.visible = true
        }
    }

    function closePopup() {
        if (!root.popupOpen) return
        root.popupOpen = false
        closeFade.restart()
    }

    function openDetails(target) {
        if (!root.visible) {
            root.emitDetailsRequest(target)
            return
        }
        root.pendingDetailsTarget = target
        root.popupOpen = false
        closeFade.restart()
    }

    function emitDetailsRequest(target) {
        if (target === "recording") root.openRecordingDetailsRequested()
        else if (target === "session") {
            root.sessionActionsActive = true
            sessionActionsPopup.open()
        }
    }

    Timer {
        id: closeFade
        interval: root.theme.motionTransientFadeDuration
        repeat: false
        onTriggered: {
            if (!root.popupOpen) {
                root.visible = false
                const target = root.pendingDetailsTarget
                root.pendingDetailsTarget = ""
                if (target.length > 0) root.emitDetailsRequest(target)
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            card.forceActiveFocus()
        } else if (root.popupOpen) {
            root.popupOpen = false
            closeFade.stop()
        }
    }

    onPopupOpenChanged: {
        if (popupOpen) {
            brightnessState.refresh()
            gameState.refresh()
            NightLightState.refresh()
        }
    }

    // ==========================================
    // HARDWARE PROCESSES
    // ==========================================
    CommandJson {
        id: brightnessState
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/brightness-status.py"]
        interval: root.popupOpen ? 2500 : 0
        autoStart: false
        onPayloadChanged: {
            const result = brightnessState.payload ?? ({})
            root.brightnessAvailable = Boolean(result.ok) && Boolean(result.available)
            if (root.brightnessAvailable && !root.brightnessChanging)
                root.brightness = Math.max(0, Math.min(100, Number(result.brightness ?? 0)))
        }
    }

    CommandJson {
        id: gameState
        command: ["python3", "-B", Quickshell.shellDir + "/scripts/game-status.py"]
        interval: root.popupOpen ? 5000 : 0
        autoStart: false
    }

    SessionActionsPopup {
        id: sessionActionsPopup
        theme: root.theme
        target: root.target
        ownerActive: root.sessionActionsActive
        onActionRequested: function(action) {
            Quickshell.execDetached([
                Quickshell.shellDir + "/scripts/session-action.sh",
                action
            ])
        }
        onVisibleChanged: if (!visible) root.sessionActionsActive = false
    }

    CommandAction {
        id: brightnessSetAction
        baseCommand: ["python3", "-B", Quickshell.shellDir + "/scripts/brightness-action.py"]
        fallbackError: "Não foi possível alterar o brilho."
    }

    function setBrightness(percent) {
        const v = Math.max(1, Math.min(100, Math.round(percent)))
        root.brightness = v
        root.brightnessChanging = true
        brightnessSetAction.run(["set", String(v)])
        brightnessDebounce.restart()
    }

    Timer {
        id: brightnessDebounce
        interval: 300
        repeat: false
        onTriggered: root.brightnessChanging = false
    }

    PopupCard {
        id: card
        theme: root.theme
        cardColor: root.theme.popupBackground
        opened: root.popupOpen
        width: root.theme.popupWidths.large
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        implicitHeight: mainCol.implicitHeight + root.theme.popupInsets.large * 2
        frameColor: root.theme.glassBorder
        Keys.onEscapePressed: root.closePopup()

        Column {
            id: mainCol
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.panel
            spacing: root.theme.spacingTokens.lg

            // 0. HEADER DOS CONTROLES COM BOTÃO DE MIXER
            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 30
                horizontalInset: 0
                topInset: 0
                iconBoxSize: 0
                title: "CONTROLES RÁPIDOS"
                titleColor: root.theme.surfaceVariantForeground
                titlePixelSize: root.theme.typeTokens.meta
                titleWeight: Font.DemiBold
                titleLetterSpacing: 0.5
                actionSpacing: root.theme.spacingTokens.xsPlus

                PopupIconButton {
                    width: 28
                    height: 28
                    radius: root.theme.radiusButton
                    theme: root.theme
                    tablerIcon: "power"
                    iconPixelSize: root.theme.iconTokens.mdPlus
                    normalBackground: "transparent"
                    hoverBackground: root.theme.glassHoverSurface
                    normalForeground: root.theme.surfaceVariantForeground
                    hoverForeground: root.theme.foreground
                    onClicked: root.openDetails("session")
                }
            }

            // 1. SLIDERS DE SAÍDA, ENTRADA E BRILHO
            Rectangle {
                width: parent.width
                height: slidersColumn.implicitHeight + root.theme.spacingTokens.md * 2
                radius: root.theme.radiusXl
                color: root.theme.adaptiveCardSurface
                border.width: 1
                border.color: root.theme.adaptiveCardBorder

                Column {
                    id: slidersColumn
                    anchors.fill: parent
                    anchors.margins: root.theme.spacingTokens.md
                    spacing: root.theme.spacingTokens.xs

                    SliderRow {
                        width: parent.width
                        implicitHeight: 24
                        theme: root.theme
                        tablerIcon: root.sink?.audio?.muted ? "bar-volume-off" : "bar-volume"
                        iconClickable: true
                        value: root.sink?.audio ? root.sink.audio.volume : 0
                        maximum: 1.5
                        showValue: false
                        trackRightInset: root.theme.popupInsets.standard
                        thumbAlwaysVisible: true
                        accent: root.sink?.audio?.muted ? root.theme.red : root.theme.primary
                        available: Boolean(root.sink?.audio)
                        onValueRequested: function(val) {
                            if (root.sink?.audio)
                                root.sink.audio.volume = val
                        }
                        onIconActivated: {
                            if (root.sink?.audio)
                                root.sink.audio.muted = !root.sink.audio.muted
                        }
                    }

                    SliderRow {
                        width: parent.width
                        implicitHeight: 24
                        theme: root.theme
                        tablerIcon: root.source?.audio?.muted ? "microphone-off" : "microphone"
                        iconClickable: true
                        value: root.source?.audio ? root.source.audio.volume : 0
                        maximum: 1.5
                        showValue: false
                        trackRightInset: root.theme.popupInsets.standard
                        thumbAlwaysVisible: true
                        accent: root.source?.audio?.muted ? root.theme.red : root.theme.pink
                        available: Boolean(root.source?.audio)
                        onValueRequested: function(val) {
                            if (root.source?.audio)
                                root.source.audio.volume = val
                        }
                        onIconActivated: {
                            if (root.source?.audio)
                                root.source.audio.muted = !root.source.audio.muted
                        }
                    }

                    SliderRow {
                        width: parent.width
                        implicitHeight: 24
                        theme: root.theme
                        tablerIcon: "bar-sun"
                        value: root.brightness
                        maximum: 100
                        showValue: false
                        trackRightInset: root.theme.popupInsets.standard
                        thumbAlwaysVisible: true
                        accent: root.theme.yellow
                        available: root.brightnessAvailable
                        onValueRequested: function(val) {
                            root.setBrightness(val)
                        }
                    }
                }
            }

            // 2. CONTROLES DE ESTADO
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: root.theme.spacingTokens.lg
                rowSpacing: root.theme.spacingTokens.lg

                QuickTile {
                    width: (parent.width - root.theme.spacingTokens.lg) / 2
                    height: 44
                    theme: root.theme
                    tablerIcon: "bar-moon"
                    title: "Não perturbe"
                    subtitle: NotificationState.dnd ? "Ativo" : "Desativado"
                    active: NotificationState.dnd
                    accent: root.theme.primary
                    onClicked: NotificationState.toggleDnd()
                }

                QuickTile {
                    width: (parent.width - root.theme.spacingTokens.lg) / 2
                    height: 44
                    theme: root.theme
                    tablerIcon: "bar-coffee"
                    title: "Inibir suspensão"
                    subtitle: IdleState.inhibited ? "Ativo" : "Desativado"
                    active: IdleState.inhibited
                    accent: root.theme.yellow
                    onClicked: IdleState.inhibited = !IdleState.inhibited
                }

                QuickTile {
                    width: (parent.width - root.theme.spacingTokens.lg) / 2
                    height: 44
                    theme: root.theme
                    tablerIcon: root.recordingActive && root.recordingHasAudio
                                ? "bar-record-audio"
                                : "bar-record"
                    title: "Gravar tela"
                    subtitle: root.recordingActive
                              ? ("Gravando " + root.recordingElapsedText)
                              : "Capturar vídeo"
                    active: root.recordingActive
                    accent: root.theme.red
                    hasDetail: true
                    onClicked: {
                        if (root.recordingActive) {
                            ScreenRecordingState.stop()
                            root.stopRecordingRequested()
                        } else {
                            root.openDetails("recording")
                        }
                    }
                    onDetailClicked: {
                        root.openDetails("recording")
                    }
                }

                QuickTile {
                    width: (parent.width - root.theme.spacingTokens.lg) / 2
                    height: 44
                    theme: root.theme
                    tablerIcon: "bar-sun"
                    title: "Luz noturna"
                    subtitle: NightLightState.nightLightEnabled
                              ? (NightLightState.active ? NightLightState.currentTemp + "K" : "Dia")
                              : (NightLightState.sunset.length > 0 && NightLightState.sunset !== "--:--"
                                 ? NightLightState.sunset : "Desligada")
                    active: NightLightState.nightLightEnabled
                    accent: root.theme.yellow
                    onClicked: NightLightState.toggle()
                }

            }

            // Ações informativas ficam em linhas compactas, fora da grade de toggles.
            Column {
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                PopupListRow {
                    id: gamesRow
                    visible: root.gameActive
                    theme: root.theme
                    rowHeight: 38
                    cornerRadius: root.theme.radiusMd
                    hoverEnabled: false
                    leadingTablerIcon: "bar-game"
                    leadingIconColor: root.theme.green
                    leadingIconPixelSize: root.theme.iconTokens.md
                    title: root.runningGames.length > 1
                        ? root.runningGames.length + " jogos em execução"
                        : "Jogo em execução"
                    titlePixelSize: root.theme.typeTokens.body
                    subtitle: root.runningGames.length > 1
                        ? root.runningGames.map(game => String(game.name ?? "Jogo")).join(", ")
                        : String(root.runningGames[0]?.name ?? "")
                    subtitlePixelSize: root.theme.typeTokens.meta
                }

            }

            // 3. MÍDIA COMPLETA (controles MPRIS e troca de reprodutor)
            QuickMediaPlayer {
                visible: root.hasMedia
                theme: root.theme
                player: root.currentMedia
                players: MediaState.players.filter(p => p && (p.isPlaying || String(p.trackTitle ?? "").trim().length > 0))
                onPlayerSelected: function(selected) { MediaState.selectPlayer(selected) }
            }

            // 4. DIVISOR
            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.glassBorderSubtle
            }

            // 5. HEADER DAS NOTIFICAÇÕES
            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 24
                horizontalInset: 0
                topInset: 0
                iconBoxSize: root.theme.iconTokens.smPlus
                iconBoxColor: "transparent"
                iconPixelSize: root.theme.iconTokens.smPlus
                contentGap: root.theme.spacingTokens.xsPlus
                leadingTablerIcon: "bell"
                leadingIconColor: root.theme.primary
                title: "Notificações"
                titlePixelSize: root.theme.typeTokens.body
                titleWeight: Font.DemiBold
                actionSpacing: root.theme.spacingTokens.sm

                titleAccessory: Component {
                    Rectangle {
                        visible: NotificationState.count > 0
                        width: Math.max(root.theme.radiusMd * 2, countText.implicitWidth + root.theme.spacingTokens.sm)
                        height: root.theme.radiusMd * 2
                        radius: root.theme.radiusMd
                        color: root.theme.glassCardSurface

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: "" + NotificationState.count
                            color: root.theme.surfaceVariantForeground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // Botão Limpar Tudo
                Rectangle {
                    visible: NotificationState.count > 0
                    width: clearRow.implicitWidth + root.theme.spacingTokens.xsPlus * 2
                    height: 22
                    radius: root.theme.pillRadius
                    color: clearHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                    border.width: 1
                    border.color: clearHover.hovered ? root.theme.pillBorderHover : root.theme.glassBorderSubtle

                    Row {
                        id: clearRow
                        anchors.centerIn: parent
                        spacing: root.theme.spacingTokens.xs

                        Text {
                            text: "×"
                            color: clearHover.hovered ? root.theme.foreground : root.theme.surfaceVariantForeground
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.titleMedium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Limpar tudo"
                            color: clearHover.hovered ? root.theme.foreground : root.theme.offWhite
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.meta
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: NotificationState.clearAll() }
                }
            }

            Text {
                visible: NotificationState.notificationStoreWarning.length > 0
                width: parent.width
                text: NotificationState.notificationStoreWarning
                color: root.theme.yellow
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                wrapMode: Text.WordWrap
            }

            // 6. EMPTY STATE (quando não há notificações)
            Item {
                visible: NotificationState.count === 0
                width: parent.width
                height: 60
                implicitHeight: visible ? 60 : 0

                EmptyState {
                    anchors.fill: parent
                    theme: root.theme
                    title: "Sem notificações"
                    subtitle: "Tudo limpo por aqui"
                    titleSize: root.theme.typeTokens.body
                    subtitleSize: root.theme.typeTokens.meta
                    titleColor: root.theme.offWhite
                    subtitleColor: root.theme.surfaceVariantForeground
                }
            }

            // 7. LISTA DE NOTIFICAÇÕES (quando há notificações)
            ScrollableList {
                id: notifListView
                theme: root.theme
                visible: NotificationState.count > 0
                width: parent.width
                height: root.availableNotifHeight
                implicitHeight: visible ? root.availableNotifHeight : 0
                // Release delegates and avoid regrouping history while closed.
                // root.visible remains true through the popup exit animation.
                model: root.visible
                    ? NotificationContent.historyRows(NotificationState.tracked, root.expandedNotificationGroups)
                    : null
                contentSpacing: 0
                showScrollBar: true
                reserveScrollBarSpace: false
                clipContent: !root.swipeDismissActive
                scrollBarThumbColor: root.theme.primary
                scrollBarHoverOpacity: 1

                delegate: Component {
                    Item {
                        id: historyRow
                        required property var modelData
                        width: notifListView.viewWidth
                        implicitHeight: groupContent.implicitHeight
                            + (modelData.last ? root.theme.spacingTokens.lg : 0)
                        height: implicitHeight

                        Behavior on height {
                            enabled: root.theme.qmlAnimationsEnabled
                            NumberAnimation { duration: root.theme.motionLayout; easing.type: root.theme.motionEasing }
                        }

                        // Continuous group surface across virtualized rows. Only the
                        // first/last rows have rounded outer ends; each item still swipes.
                        Rectangle {
                            id: groupSurface
                            width: parent.width
                            height: groupContent.implicitHeight
                            radius: root.theme.radiusLg
                            color: root.theme.glassCardSurface
                            topLeftRadius: historyRow.modelData.first ? groupSurface.radius : 0
                            topRightRadius: groupSurface.topLeftRadius
                            bottomLeftRadius: historyRow.modelData.last ? groupSurface.radius : 0
                            bottomRightRadius: groupSurface.bottomLeftRadius
                        }

                        Column {
                            id: groupContent
                            width: parent.width
                            spacing: 0

                            PopupListRow {
                                theme: root.theme
                                width: parent.width
                                visible: historyRow.modelData.header
                                rowHeight: 34
                                leadingSlotWidth: 38
                                leadingIconPixelSize: root.theme.iconTokens.lg
                                titlePixelSize: root.theme.typeTokens.subtitle
                                titleColor: root.theme.surfaceVariantForeground
                                title: historyRow.modelData.name
                                       + (historyRow.modelData.count > 1
                                          ? " · " + historyRow.modelData.count : "")
                                leadingImage: NotificationState.resolveIcon(historyRow.modelData.notification)
                                leadingTablerIcon: "bell"
                                idleColor: "transparent"
                                idleBorderWidth: 0
                                active: activeFocus
                                activeFocusOnTab: visible && historyRow.modelData.count > 1
                                cursorShape: historyRow.modelData.count > 1
                                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: title + (historyRow.modelData.count > 1
                                    ? (historyRow.modelData.expanded ? ", recolher" : ", expandir") : "")
                                Keys.onReturnPressed: {
                                    if (historyRow.modelData.count > 1)
                                        root.toggleNotificationGroup(historyRow.modelData.key)
                                }
                                Keys.onSpacePressed: {
                                    if (historyRow.modelData.count > 1)
                                        root.toggleNotificationGroup(historyRow.modelData.key)
                                }
                                Keys.onRightPressed: {
                                    if (historyRow.modelData.count > 1 && !historyRow.modelData.expanded)
                                        root.toggleNotificationGroup(historyRow.modelData.key)
                                }
                                Keys.onLeftPressed: {
                                    if (historyRow.modelData.count > 1 && historyRow.modelData.expanded)
                                        root.toggleNotificationGroup(historyRow.modelData.key)
                                }
                                trailing: Component {
                                    Row {
                                        spacing: root.theme.spacingTokens.xs
                                        PopupIconButton {
                                            theme: root.theme
                                            tablerIcon: "dashboard-trash"
                                            iconPixelSize: root.theme.iconTokens.smPlus
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            Accessible.role: Accessible.Button
                                            Accessible.name: "Dispensar grupo " + historyRow.modelData.name
                                            onClicked: NotificationState.dismissGroup(historyRow.modelData.key)
                                        }
                                        Text {
                                            visible: historyRow.modelData.count > 1
                                            text: historyRow.modelData.expanded ? "󰅃" : "󰅀"
                                            color: root.theme.offWhite
                                            font.family: root.theme.nerdFontFamily
                                            font.pixelSize: root.theme.iconTokens.md
                                            width: root.theme.iconTokens.md
                                            height: 26
                                            anchors.verticalCenter: parent.verticalCenter
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                                interactionHandlers: [
                                    TapHandler {
                                        enabled: historyRow.modelData.count > 1
                                        onTapped: function(eventPoint) {
                                            const trailingRight = historyRow.width
                                                - root.theme.popupInsets.compact
                                            const dismissRight = trailingRight
                                                - root.theme.iconTokens.md
                                                - root.theme.spacingTokens.xs
                                            const dismissLeft = dismissRight - 26
                                            if (eventPoint.position.x >= dismissLeft
                                                    && eventPoint.position.x <= dismissRight) {
                                                NotificationState.dismissGroup(historyRow.modelData.key)
                                                return
                                            }
                                            root.toggleNotificationGroup(historyRow.modelData.key)
                                        }
                                    }
                                ]
                            }

                            Rectangle {
                                id: notifItemCard
                                readonly property var modelData: historyRow.modelData.notification
                                property real swipeOffset: 0
                                property real swipeDistance: 0

                                readonly property bool isCritical: notifItemCard.modelData && notifItemCard.modelData.urgency === NotificationUrgency.Critical
                                readonly property bool hasContent: NotificationState.notificationHasUsefulContent(notifItemCard.modelData)

                                visible: hasContent
                                width: notifListView.viewWidth
                                x: swipeOffset
                                height: implicitHeight
                                implicitHeight: hasContent ? (notifContentCol.implicitHeight + 16) : 0
                                radius: root.theme.radiusLg
                                color: notifHover.hovered || swipeOffset !== 0
                                    ? root.theme.glassHoverSurface : "transparent"
                                border.width: isCritical ? 1 : 0
                                border.color: isCritical
                                              ? root.theme.red
                                              : (notifHover.hovered ? root.theme.pillBorderHover : root.theme.adaptiveCardBorder)

                                Behavior on color {
                                    enabled: root.theme.qmlAnimationsEnabled
                                    ColorAnimation {
                                        duration: root.theme.motionFast
                                        easing.type: root.theme.motionEasing
                                    }
                                }
                                Behavior on border.color {
                                    enabled: root.theme.qmlAnimationsEnabled
                                    ColorAnimation {
                                        duration: root.theme.motionFast
                                        easing.type: root.theme.motionEasing
                                    }
                                }

                                HoverHandler {
                                    id: notifHover
                                }

                                DragHandler {
                                    id: notificationSwipe
                                    target: null
                                    xAxis.enabled: true
                                    yAxis.enabled: false
                                    onActiveChanged: {
                                        if (active) {
                                            notifItemCard.swipeDistance = 0
                                            root.swipeDismissActive = true
                                            swipeReturnAnimation.stop()
                                            swipeDismissAnimation.stop()
                                            return
                                        }
                                        const distance = notifItemCard.swipeDistance
                                        if (distance <= -Math.max(72, notifItemCard.width * 0.28)) {
                                            swipeDismissAnimation.to = -root.swipeRunway
                                                - notifItemCard.width - root.theme.popupInsets.panel
                                            swipeDismissAnimation.start()
                                        } else {
                                            swipeReturnAnimation.start()
                                        }
                                    }
                                    onTranslationChanged: {
                                        if (active) {
                                            notifItemCard.swipeDistance = translation.x
                                            notifItemCard.swipeOffset = Math.max(
                                                -root.swipeRunway, Math.min(0, translation.x))
                                        }
                                    }
                                }

                                NumberAnimation {
                                    id: swipeReturnAnimation
                                    target: notifItemCard
                                    property: "swipeOffset"
                                    to: 0
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                    onFinished: root.swipeDismissActive = false
                                }

                                NumberAnimation {
                                    id: swipeDismissAnimation
                                    target: notifItemCard
                                    property: "swipeOffset"
                                    duration: 150
                                    easing.type: Easing.InCubic
                                    onFinished: {
                                        NotificationState.dismissFromHistory(notifItemCard.modelData)
                                        root.swipeDismissActive = false
                                    }
                                }

                                NotificationCardContent {
                                    id: notifContentCol
                                    theme: root.theme
                                    notification: notifItemCard.modelData
                                    compact: true
                                    historyLayout: true
                                    expanded: notifHover.hovered
                                    dismissible: true
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: root.theme.popupInsets.compact
                                    onActivated: root.closePopup()
                                    onDismissRequested: {
                                        NotificationState.dismissFromHistory(notifItemCard.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                footer: Component {
                    Item {
                        width: notifListView.viewWidth
                        height: root.theme.spacingTokens.md
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.closePopup()
    }
}
