import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property string ssid: ""
    property string uuid: ""
    property string errorText: ""
    property bool busy: false
    property bool showPassword: false

    signal connectRequested(string ssid, string password)

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: root.theme.popupWidths.medium
    implicitHeight: 184
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true


    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.visible = false
    }

    function openFor(networkName, profileUuid) {
        ssid = networkName
        uuid = profileUuid === undefined ? "" : String(profileUuid)
        showPassword = false
        passwordField.text = ""
        visible = true
        passwordField.forceActiveFocus()
    }

    function submit() {
        if (busy || passwordField.text.length === 0) return
        const value = passwordField.text
        passwordField.text = ""
        showPassword = false
        connectRequested(ssid, value)
    }

    onVisibleChanged: {
        if (visible) passwordField.forceActiveFocus()
        else {
            passwordField.text = ""
            showPassword = false
        }
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        focus: true

        Column {
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.outer
            spacing: root.theme.spacingTokens.lg

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 42
                title: "Conectar ao Wi‑Fi"
                titlePixelSize: root.theme.typeTokens.titleMedium
                titleWeight: Font.Bold
                subtitle: root.ssid
                subtitleColor: root.theme.cyan
                subtitlePixelSize: root.theme.typeTokens.subtitle
                subtitleSpacing: root.theme.spacingTokens.lg
            }

            Rectangle {
                width: parent.width
                height: 34
                radius: root.theme.radiusSm
                color: root.theme.glassCardSurface
                border.width: 1
                border.color: passwordField.activeFocus ? root.theme.primary : root.theme.borderRegular

                SearchField {
                    id: passwordField
                    theme: root.theme
                    anchors.left: parent.left
                    anchors.right: eyeButton.left
                    anchors.leftMargin: root.theme.popupInsets.standard
                    anchors.rightMargin: root.theme.spacingTokens.xs
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: "Senha da rede"
                    placeholderColor: root.theme.grey
                    placeholderWhileFocused: false
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.bodyEmphasis
                    enabled: !root.busy
                    onAccepted: root.submit()
                }

                Item {
                    id: eyeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 32

                    Text {
                        anchors.centerIn: parent
                        text: root.showPassword ? "󰈈" : "󰈉"
                        color: eyeHover.hovered ? root.theme.primary : root.theme.offWhite
                        font.family: root.theme.nerdFontFamily
                        font.pixelSize: root.theme.iconTokens.lg
                    }

                    HoverHandler { id: eyeHover }
                    TapHandler { onTapped: root.showPassword = !root.showPassword }
                }
            }

            Text {
                width: parent.width
                height: 18
                text: root.busy ? "Conectando…" : root.errorText
                color: root.busy ? root.theme.primary : root.theme.red
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.body
                elide: Text.ElideRight
            }

            Row {
                anchors.right: parent.right
                spacing: root.theme.spacingTokens.md

                Rectangle {
                    width: 76
                    height: 28
                    radius: root.theme.radiusSm
                    color: cancelHover.hovered ? root.theme.glassHoverSurface : root.theme.glassCardSurface
                    Text {
                        anchors.centerIn: parent
                        text: "Cancelar"
                        color: root.theme.offWhite
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                    }
                    HoverHandler { id: cancelHover }
                    TapHandler { onTapped: root.visible = false }
                }

                Rectangle {
                    width: 78
                    height: 28
                    radius: root.theme.radiusSm
                    opacity: root.busy ? 0.5 : 1
                    color: connectHover.hovered ? root.theme.withAlpha(root.theme.primary, 0.85) : root.theme.primary
                    Text {
                        anchors.centerIn: parent
                        text: "Conectar"
                        color: root.theme.primaryForeground
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.theme.typeTokens.body
                        font.weight: Font.DemiBold
                    }
                    HoverHandler { id: connectHover }
                    TapHandler { enabled: !root.busy; onTapped: root.submit() }
                }
            }
        }
    }
}
