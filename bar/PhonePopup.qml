// LEGADO: popup do módulo KDE Connect não montado no shell atual (bar/Phone.qml).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QtQuick.Dialogs
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property var phoneData: ({})
    property bool busy: false
    property string busyTarget: ""
    property string errorText: ""
    property string errorTarget: ""
    property string shareTargetId: ""
    property string shareDraft: ""

    signal refreshRequested()
    signal pingRequested(string deviceId)
    signal ringRequested(string deviceId)
    signal pairRequested(string deviceId)
    signal unpairRequested(string deviceId)
    signal shareTextRequested(string deviceId, string message)
    signal shareFileRequested(string deviceId, string path)
    signal settingsRequested()

    readonly property var devices: phoneData?.devices ?? []
    readonly property var reachable: devices.filter(function(d) { return Boolean(d.reachable) })
    readonly property var offline: devices.filter(function(d) { return !Boolean(d.reachable) })
    readonly property bool daemon: phoneData?.daemon !== false
    readonly property string shareTargetName: {
        for (let i = 0; i < devices.length; i++) {
            if (String(devices[i].id) === root.shareTargetId)
                return String(devices[i].name || devices[i].id)
        }
        return ""
    }

    function batteryIcon(p) {
        const v = Number(p)
        if (v < 0) return ""
        if (v >= 90) return "󰁹"
        if (v >= 70) return "󰂁"
        if (v >= 50) return "󰁿"
        if (v >= 30) return "󰁽"
        if (v >= 15) return "󰁻"
        return "󰁺"
    }

    function statusLine(d) {
        const key = "device:" + String(d.id)
        if (root.busyTarget === key)
            return "Aplicando…"
        if (root.errorTarget === key && root.errorText.length > 0)
            return root.errorText
        if (d.reachable && d.paired)
            return "Conectado"
        if (d.reachable && !d.paired)
            return "Aguardando pareamento"
        if (!d.reachable && d.paired)
            return "Pareado • offline"
        return "Encontrado"
    }

    function statusColor(d) {
        const key = "device:" + String(d.id)
        if (root.errorTarget === key && root.errorText.length > 0)
            return root.theme.red
        if (root.busyTarget === key)
            return root.theme.primary
        if (d.reachable && d.paired)
            return root.theme.primary
        return root.theme.foreground
    }

    function fileUrlToPath(url) {
        let s = String(url)
        if (s.startsWith("file://"))
            s = s.replace(/^file:\/\//, "")
        try {
            s = decodeURIComponent(s)
        } catch (e) {}
        return s
    }

    onDevicesChanged: {
        // Keep the share target valid; default to the first reachable device.
        let ok = false
        for (let i = 0; i < reachable.length; i++) {
            if (String(reachable[i].id) === root.shareTargetId) {
                ok = true
                break
            }
        }
        if (!ok)
            root.shareTargetId = reachable.length > 0 ? String(reachable[0].id) : ""
    }

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: root.theme.popupWidths.large
    implicitHeight: Math.min(540, 87 + 12 + Math.min(330, scrollContent.implicitHeight) + (reachable.length > 0 ? 86 : 0))

    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            card.forceActiveFocus()
            refreshRequested()
        }
    }

    FileDialog {
        id: filePicker
        title: "Compartilhar arquivo com " + (root.shareTargetName.length > 0 ? root.shareTargetName : "o telefone")
        fileMode: FileDialog.OpenFile
        property string deviceId: ""
        onAccepted: {
            if (deviceId.length > 0 && selectedFile.toString().length > 0)
                root.shareFileRequested(deviceId, root.fileUrlToPath(selectedFile))
        }
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        cardClip: true

        Keys.onEscapePressed: root.visible = false

        PopupHeader {
            id: headerSection
            theme: root.theme
            leadingTablerIcon: "device-mobile"
            leadingIconColor: root.reachable.length > 0 ? root.theme.primary : root.theme.grey
            title: "Telefone"
            subtitle: {
                if (!root.daemon) return "KDE Connect indisponível"
                if (root.devices.length === 0) return "Nenhum dispositivo"
                if (root.reachable.length === 0) return "Nenhum dispositivo disponível"
                return root.reachable.length + (root.reachable.length === 1
                    ? " dispositivo disponível"
                    : " dispositivos disponíveis")
            }
            subtitleColor: root.reachable.length > 0 ? root.theme.primary : root.theme.surfaceVariantForeground

            PopupIconButton {
                width: 26
                height: 26
                radius: root.theme.radiusSm
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                tablerIcon: "bar-refresh"
                iconPixelSize: root.theme.iconTokens.md
                onClicked: root.refreshRequested()
            }

            PopupSettingsButton {
                width: 26
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                theme: root.theme
                onClicked: root.settingsRequested()
            }
        }

        Rectangle {
            id: divider
            anchors.top: headerSection.bottom
            anchors.topMargin: root.theme.popupInsets.standard
            anchors.left: parent.left
            anchors.leftMargin: root.theme.popupInsets.outer
            anchors.right: parent.right
            anchors.rightMargin: root.theme.popupInsets.outer
            height: 1
            color: root.theme.outlineVariant
        }

        Flickable {
            id: scrollArea
            anchors.top: divider.bottom
            anchors.topMargin: root.theme.popupInsets.standard
            anchors.left: parent.left
            anchors.leftMargin: root.theme.popupInsets.outer
            anchors.right: parent.right
            anchors.rightMargin: root.theme.popupInsets.outer
            anchors.bottom: shareSection.top
            anchors.bottomMargin: root.theme.popupInsets.standard
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: scrollContent.implicitHeight

            WheelKinetic { scrollTarget: scrollArea }

            Column {
                id: scrollContent
                width: parent.width
                spacing: root.theme.spacingTokens.lg

                Item {
                    visible: root.devices.length === 0
                    width: parent.width
                    height: 48

                    Text {
                        anchors.centerIn: parent
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.daemon ? "Pareie no app KDE Connect (mesma rede) e atualize." : "Instale o pacote kdeconnect e inicie o daemon."
                        color: root.theme.surfaceVariantForeground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                    }
                }

                Column {
                    visible: root.reachable.length > 0
                    width: parent.width
                    spacing: root.theme.spacingTokens.xsPlus

                    Text {
                        text: "DISPONÍVEIS"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    Column {
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.reachable

                            delegate: PopupListRow {
                                id: reachablePhoneDelegate
                                theme: root.theme
                                required property var modelData
                                rowHeight: 64
                                hoverBorderColor: root.theme.withAlpha(root.theme.border, 0.20)

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: root.theme.popupInsets.standard
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.theme.popupInsets.standard
                                    anchors.top: parent.top
                                    anchors.topMargin: root.theme.popupInsets.smallPlus
                                    spacing: root.theme.spacingTokens.mdPlus

                                    TablerIcon {
                                        width: root.theme.iconTokens.lgPlus
                                        height: root.theme.iconTokens.lgPlus
                                        iconName: "device-mobile"
                                        iconColor: root.theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - 32
                                        spacing: root.theme.spacingTokens.micro

                                        Text {
                                            width: parent.width
                                            text: String(reachablePhoneDelegate.modelData.name || reachablePhoneDelegate.modelData.id)
                                            color: root.theme.foreground
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.subtitle
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        Row {
                                            spacing: root.theme.spacingTokens.xsPlus

                                            Text {
                                                text: root.statusLine(reachablePhoneDelegate.modelData)
                                                color: root.statusColor(reachablePhoneDelegate.modelData)
                                                font.family: root.theme.fontFamily
                                                font.pixelSize: root.theme.typeTokens.caption
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: Number(reachablePhoneDelegate.modelData.battery) >= 0
                                                text: "• " + root.batteryIcon(reachablePhoneDelegate.modelData.battery) + " " + reachablePhoneDelegate.modelData.battery + "%"
                                                color: root.theme.offWhite
                                                font.family: root.theme.fontFamily
                                                font.pixelSize: root.theme.typeTokens.caption
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: root.theme.popupInsets.standard
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.theme.popupInsets.standard
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: root.theme.popupInsets.small
                                    spacing: root.theme.spacingTokens.xsPlus

                                    Rectangle {
                                        width: 60
                                        height: 22
                                        radius: root.theme.radiusSm
                                        color: pingHover.hovered ? root.theme.withAlpha(root.theme.primary, 0.25) : root.theme.withAlpha(root.theme.primary, 0.12)
                                        border.width: 1
                                        border.color: root.theme.withAlpha(root.theme.primary, 0.30)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Avisar"
                                            color: root.theme.primary
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            font.weight: Font.DemiBold
                                        }

                                        HoverHandler { id: pingHover }
                                        TapHandler { onTapped: root.pingRequested(String(reachablePhoneDelegate.modelData.id)) }
                                    }

                                    Rectangle {
                                        width: 86
                                        height: 22
                                        radius: root.theme.radiusSm
                                        color: ringHover.hovered ? root.theme.withAlpha(root.theme.primary, 0.25) : root.theme.withAlpha(root.theme.primary, 0.12)
                                        border.width: 1
                                        border.color: root.theme.withAlpha(root.theme.primary, 0.30)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Fazer tocar"
                                            color: root.theme.primary
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            font.weight: Font.DemiBold
                                        }

                                        HoverHandler { id: ringHover }
                                        TapHandler { onTapped: root.ringRequested(String(reachablePhoneDelegate.modelData.id)) }
                                    }

                                    Rectangle {
                                        width: 90
                                        height: 22
                                        radius: root.theme.radiusSm
                                        color: fileHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                                        border.width: 1
                                        border.color: root.theme.withAlpha(root.theme.border, 0.30)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Enviar arquivo"
                                            color: root.theme.offWhite
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            font.weight: Font.DemiBold
                                        }

                                        HoverHandler { id: fileHover }
                                        TapHandler {
                                            onTapped: {
                                                root.shareTargetId = String(reachablePhoneDelegate.modelData.id)
                                                filePicker.deviceId = String(reachablePhoneDelegate.modelData.id)
                                                filePicker.open()
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: !Boolean(reachablePhoneDelegate.modelData.paired)
                                        width: 56
                                        height: 22
                                        radius: root.theme.radiusSm
                                        color: pairHover.hovered ? root.theme.withAlpha(root.theme.primary, 0.25) : root.theme.withAlpha(root.theme.primary, 0.12)
                                        border.width: 1
                                        border.color: root.theme.withAlpha(root.theme.primary, 0.30)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Parear"
                                            color: root.theme.primary
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: root.theme.typeTokens.caption
                                            font.weight: Font.DemiBold
                                        }

                                        HoverHandler { id: pairHover }
                                        TapHandler { onTapped: root.pairRequested(String(reachablePhoneDelegate.modelData.id)) }
                                    }
                                }

                            }
                        }
                    }
                }

                Column {
                    visible: root.offline.length > 0
                    width: parent.width
                    spacing: root.theme.spacingTokens.xsPlus

                    Text {
                        text: "OFFLINE"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.meta
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    Column {
                        width: parent.width
                        spacing: root.theme.spacingTokens.xs

                        Repeater {
                            model: root.offline

                            delegate: PopupListRow {
                                id: offlinePhoneDelegate
                                theme: root.theme
                                required property var modelData
                                rowHeight: 42
                                hoverBorderColor: root.theme.withAlpha(root.theme.border, 0.15)
                                leadingTablerIcon: "device-mobile"
                                leadingIconColor: root.theme.grey
                                leadingIconPixelSize: root.theme.iconTokens.lgPlus
                                title: String(offlinePhoneDelegate.modelData.name || offlinePhoneDelegate.modelData.id)
                                subtitle: root.statusLine(offlinePhoneDelegate.modelData)
                                subtitleColor: root.statusColor(offlinePhoneDelegate.modelData)
                                trailing: Rectangle {
                                    width: 70
                                    height: 24
                                    radius: root.theme.radiusSm
                                    visible: Boolean(offlinePhoneDelegate.modelData.paired)
                                    color: offForgetHover.hovered ? root.theme.withAlpha(root.theme.red, 0.25) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Esquecer"
                                        color: root.theme.red
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.caption
                                        font.weight: Font.DemiBold
                                    }

                                    HoverHandler { id: offForgetHover }
                                    TapHandler { onTapped: root.unpairRequested(String(offlinePhoneDelegate.modelData.id)) }
                                }

                            }
                        }
                    }
                }
            }
        }

        Item {
            id: shareSection
            visible: root.reachable.length > 0
            anchors.left: parent.left
            anchors.leftMargin: root.theme.popupInsets.outer
            anchors.right: parent.right
            anchors.rightMargin: root.theme.popupInsets.outer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.theme.popupInsets.outer
            height: shareSection.visible ? 74 : 0

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: root.theme.outlineVariant
            }

            Text {
                id: shareLabel
                anchors.top: parent.top
                anchors.topMargin: root.theme.popupInsets.compact
                width: parent.width
                text: "Texto para " + (root.shareTargetName.length > 0 ? root.shareTargetName : "…")
                color: root.theme.surfaceVariantForeground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.meta
                elide: Text.ElideRight
            }

            Row {
                anchors.top: shareLabel.bottom
                anchors.topMargin: root.theme.popupInsets.small
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: root.theme.spacingTokens.sm

                Rectangle {
                    width: parent.width - 66
                    height: 30
                    radius: root.theme.radiusSm
                    color: root.theme.glassCardSurface
                    border.width: 1
                    border.color: shareInput.activeFocus ? root.theme.primary : root.theme.withAlpha(root.theme.border, 0.35)

                    SearchField {
                        id: shareInput
                        theme: root.theme
                        anchors.fill: parent
                        anchors.leftMargin: root.theme.popupInsets.compact
                        anchors.rightMargin: root.theme.popupInsets.compact
                        placeholderText: "Escreva uma mensagem…"
                        placeholderColor: root.theme.grey
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.subtitle
                        maximumLength: 4000
                        onTextChanged: root.shareDraft = text
                        Keys.onReturnPressed: {
                            if (text.trim().length > 0 && root.shareTargetId.length > 0) {
                                root.shareTextRequested(root.shareTargetId, text.trim())
                                text = ""
                            }
                        }
                    }

                }

                Rectangle {
                    width: 60
                    height: 30
                    radius: root.theme.radiusSm
                    color: sendHover.hovered ? root.theme.withAlpha(root.theme.primary, 0.28) : root.theme.glassActiveSurface
                    border.width: 1
                    border.color: root.theme.withAlpha(root.theme.primary, 0.40)

                    Text {
                        anchors.centerIn: parent
                        text: "Enviar"
                        color: root.theme.primary
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.DemiBold
                    }

                    HoverHandler { id: sendHover }
                    TapHandler {
                        onTapped: {
                            if (shareInput.text.trim().length > 0 && root.shareTargetId.length > 0) {
                                root.shareTextRequested(root.shareTargetId, shareInput.text.trim())
                                shareInput.text = ""
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: scrollIndicator
            anchors.right: parent.right
            anchors.rightMargin: root.theme.popupInsets.micro
            y: scrollArea.y + (scrollArea.contentY / Math.max(1, scrollArea.contentHeight)) * scrollArea.height
            width: 3
            height: Math.max(20, (scrollArea.height / Math.max(1, scrollArea.contentHeight)) * scrollArea.height)
            radius: 1.5
            color: root.theme.withAlpha(root.theme.foreground, 0.35)
            visible: scrollArea.contentHeight > scrollArea.height
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
