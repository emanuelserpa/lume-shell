pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target
    property var rootMenu: null
    property var currentMenu: rootMenu
    property bool canGoBack: currentMenu !== rootMenu

    // PopupAnchor metadata is incomplete in this qmllint version.
    // qmllint disable missing-property unqualified unresolved-type
    anchor.item: target
    // qmllint disable missing-type
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    // qmllint enable missing-type
    anchor.margins.top: root.theme.popupInsets.small
    // qmllint enable missing-property unqualified unresolved-type

    implicitWidth: 310
    implicitHeight: Math.min(460, menuContent.implicitHeight + 12)
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    onVisibleChanged: {

        if (visible) menuCard.forceActiveFocus()
    }

    function open(menu) {
        root.rootMenu = menu
        root.currentMenu = menu
        root.visible = menu !== null
    }

    function closeMenu() {
        root.visible = false
        root.currentMenu = root.rootMenu
    }

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    PopupCard {
        id: menuCard
        theme: root.theme
        opened: root.visible
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeMenu()

        ScrollableList {
            id: menuFlick
            theme: root.theme
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.small
            contentSpacing: root.theme.spacingTokens.tiny
            showScrollBar: true

            Column {
                id: menuContent
                width: parent.width
                spacing: root.theme.spacingTokens.tiny

                Rectangle {
                    visible: root.canGoBack
                    width: parent.width
                    height: visible ? 30 : 0
                    radius: root.theme.radiusSm
                    color: backMouse.containsMouse
                           ? root.theme.glassHoverSurface
                           : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: root.theme.popupInsets.compactPlus
                        anchors.verticalCenter: parent.verticalCenter
                        text: "  Voltar"
                        color: root.theme.isLight ? root.theme.foreground : root.theme.offWhite
                        font.family: root.theme.nerdFontFamily
                        font.pixelSize: root.theme.iconTokens.md
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.currentMenu = root.rootMenu
                    }
                }

                Repeater {
                    model: opener.children

                    delegate: PopupListRow {
                        id: menuItem
                        theme: root.theme
                        required property var modelData
                        rowHeight: modelData.isSeparator ? 7 : 30
                        cornerRadius: root.theme.radiusSm
                        idleColor: "transparent"
                        idleBorderWidth: 0
                        hoverEnabled: !modelData.isSeparator
                        cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        visible: true
                        opacity: modelData.isSeparator || modelData.enabled ? 1.0 : 0.45
                        title: menuItem.modelData.isSeparator ? "" : (menuItem.modelData.text ?? "")
                        titlePixelSize: root.theme.typeTokens.bodyEmphasis
                        leadingImage: menuItem.modelData.isSeparator ? "" : (menuItem.modelData.icon ?? "")
                        leadingIcon: (!menuItem.modelData.isSeparator
                                      && (menuItem.modelData.icon ?? "").toString().length === 0
                                      && menuItem.modelData.buttonType !== 0
                                      && menuItem.modelData.checkState === Qt.Checked) ? "✓" : ""
                        leadingIconColor: root.theme.pink
                        trailing: Text {
                            width: 10
                            text: menuItem.modelData.hasChildren ? "›" : ""
                            color: root.theme.grey
                            font.family: root.theme.fontFamily
                            font.pixelSize: root.theme.typeTokens.heading
                        }

                        Rectangle {
                            visible: menuItem.modelData.isSeparator
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: root.theme.popupInsets.small
                            anchors.rightMargin: root.theme.popupInsets.small
                            height: 1
                            color: root.theme.borderSubtle
                        }

                        interactionHandlers: TapHandler {
                            enabled: !menuItem.modelData.isSeparator && menuItem.modelData.enabled
                            onTapped: {
                                if (menuItem.modelData.hasChildren) {
                                    root.currentMenu = menuItem.modelData
                                } else {
                                    menuItem.modelData.triggered()
                                    root.closeMenu()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.closeMenu()
    }
}
