pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property bool ownerActive: false
    property bool confirmationOnly: false
    property bool confirming: false
    property int selectedIndex: 0
    property int confirmIndex: 0
    property string pendingAction: ""

    signal actionRequested(string action)

    readonly property var actions: [
        { id: "lock", title: "Bloquear", tablerIcon: "bar-lock", color: root.theme.primary, confirm: false },
        { id: "suspend", title: "Suspender", tablerIcon: "bar-moon", color: root.theme.cyan, confirm: false },
        { id: "logout", title: "Encerrar sessão", tablerIcon: "logout", color: root.theme.yellow, confirm: true },
        { id: "reboot", title: "Reiniciar", tablerIcon: "bar-refresh", color: root.theme.orange, confirm: true },
        { id: "poweroff", title: "Desligar", tablerIcon: "power", color: root.theme.red, confirm: true }
    ]
    readonly property string confirmationTitle: root.pendingAction === "logout"
        ? "Encerrar sessão?"
        : root.pendingAction === "reboot"
          ? "Reiniciar o computador?"
          : "Desligar o computador?"
    readonly property string confirmationButton: root.pendingAction === "logout"
        ? "Encerrar sessão"
        : root.pendingAction === "reboot"
          ? "Reiniciar"
          : "Desligar"

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: 232
    implicitHeight: confirming ? 176 : 236
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    function open() {
        root.confirming = false
        root.selectedIndex = 0
        root.visible = true
    }

    function openConfirmation(action) {
        root.pendingAction = action
        root.confirmIndex = 0
        root.confirming = true
        root.visible = true
    }

    function cancelConfirmation() {
        root.confirming = false
        root.pendingAction = ""
        if (root.confirmationOnly)
            root.visible = false
    }

    function chooseAction(action) {
        if (action.confirm) {
            root.pendingAction = action.id
            root.confirmIndex = 0
            root.confirming = true
            return
        }
        root.actionRequested(action.id)
        root.visible = false
    }

    function confirmPendingAction() {
        root.actionRequested(root.pendingAction)
        root.pendingAction = ""
        root.confirming = false
        root.visible = false
    }

    function activateSelection() {
        if (!root.confirming) {
            root.chooseAction(root.actions[root.selectedIndex])
        } else if (root.confirmIndex === 0) {
            root.cancelConfirmation()
        } else {
            root.confirmPendingAction()
        }
    }

    onOwnerActiveChanged: {
        if (!ownerActive)
            root.visible = false
    }

    onVisibleChanged: {
        if (visible) {
            menuCard.forceActiveFocus()
        } else {
            root.confirming = false
            root.pendingAction = ""
        }
    }

    PopupCard {
        id: menuCard
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (root.confirming) {
                root.cancelConfirmation()
            } else {
                root.visible = false
            }
        }
        Keys.onUpPressed: {
            if (root.confirming) {
                root.confirmIndex = 0
            } else {
                root.selectedIndex = (root.selectedIndex + root.actions.length - 1) % root.actions.length
            }
        }
        Keys.onDownPressed: {
            if (root.confirming) {
                root.confirmIndex = 1
            } else {
                root.selectedIndex = (root.selectedIndex + 1) % root.actions.length
            }
        }
        Keys.onLeftPressed: if (root.confirming) root.confirmIndex = 0
        Keys.onRightPressed: if (root.confirming) root.confirmIndex = 1
        Keys.onReturnPressed: root.activateSelection()
        Keys.onEnterPressed: root.activateSelection()

        Column {
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.compactPlus
            spacing: root.theme.spacingTokens.xsPlus

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                leadingTablerIcon: "power"
                leadingIconColor: root.confirming ? root.theme.red : root.theme.primary
                iconBoxSize: 26
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.glassHoverSurface
                iconPixelSize: root.theme.iconTokens.mdPlus
                contentGap: root.theme.spacingTokens.sm
                headerHeight: 28
                title: root.confirming ? root.confirmationTitle : "Sessão"
                titlePixelSize: root.theme.typeTokens.title
                titleWeight: Font.DemiBold
            }

            Column {
                visible: !root.confirming
                width: parent.width
                spacing: root.theme.spacingTokens.tiny

                Repeater {
                    model: root.actions

                    delegate: PopupListRow {
                        id: sessionActionDelegate
                        theme: root.theme
                        required property int index
                        required property var modelData
                        rowHeight: 34
                        cornerRadius: root.theme.radiusMd
                        active: root.selectedIndex === index
                        idleColor: "transparent"
                        idleBorderWidth: 0
                        activeBorderColor: root.theme.pillBorderHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: if (hovered) root.selectedIndex = sessionActionDelegate.index
                        leadingTablerIcon: sessionActionDelegate.modelData.tablerIcon
                        leadingIconColor: sessionActionDelegate.modelData.color
                        title: sessionActionDelegate.modelData.title
                        titlePixelSize: root.theme.typeTokens.bodyEmphasis
                        topDivider: sessionActionDelegate.index === 2

                        interactionHandlers: TapHandler {
                            onTapped: {
                                root.selectedIndex = sessionActionDelegate.index
                                root.chooseAction(sessionActionDelegate.modelData)
                            }
                        }
                    }
                }
            }

            Column {
                visible: root.confirming
                width: parent.width
                spacing: root.theme.spacingTokens.mdPlus

                Text {
                    width: parent.width
                    height: 48
                    text: root.pendingAction === "logout"
                          ? "Você será desconectado e os aplicativos serão encerrados."
                          : root.pendingAction === "reboot"
                            ? "O computador será reiniciado."
                            : "O computador será desligado."
                    color: root.theme.offWhite
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.subtitle
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }

                Row {
                    width: parent.width
                    height: 32
                    spacing: root.theme.spacingTokens.md

                    Repeater {
                        model: [
                            { title: "Cancelar", destructive: false },
                            { title: root.confirmationButton, destructive: true }
                        ]

                        delegate: Rectangle {
                            id: confirmationActionDelegate
                            required property int index
                            required property var modelData
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: root.theme.radiusMd
                            color: root.confirmIndex === index
                                   ? (modelData.destructive ? root.theme.red : root.theme.glassActiveSurface)
                                   : root.theme.glassCardSurface
                            border.width: 1
                            border.color: root.confirmIndex === index
                                          ? (modelData.destructive ? root.theme.red : root.theme.pillBorderHover)
                                          : root.theme.glassBorderSubtle

                            Text {
                                anchors.centerIn: parent
                                text: confirmationActionDelegate.modelData.title
                                color: root.confirmIndex === confirmationActionDelegate.index && confirmationActionDelegate.modelData.destructive
                                       ? root.theme.backgroundOpaque
                                       : root.theme.foreground
                                font.family: root.theme.fontFamily
                                font.pixelSize: root.theme.typeTokens.subtitle
                                font.weight: Font.DemiBold
                            }

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: if (hovered) root.confirmIndex = confirmationActionDelegate.index
                            }
                            TapHandler {
                                onTapped: {
                                    root.confirmIndex = confirmationActionDelegate.index
                                    root.activateSelection()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
