pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

PopupWindow {
    id: root

    required property var theme
    required property Item target

    property var printerData: ({})
    property string errorText: ""
    property bool busy: false

    signal refreshRequested()
    signal cancelRequested(string jobId)
    signal settingsRequested()
    signal queueRequested()

    readonly property var printers: printerData?.printers ?? []
    readonly property var jobs: printerData?.jobs ?? []

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
    implicitHeight: Math.min(460, 166 + printers.length * 45 + Math.min(jobs.length, 5) * 42)
    color: "transparent"
    surfaceFormat.opaque: false
    visible: false
    grabFocus: true

    onVisibleChanged: {
        if (visible) {
            card.forceActiveFocus()
        }
    }

    PopupCard {
        id: card
        theme: root.theme
        opened: root.visible
        anchors.fill: parent

        Keys.onEscapePressed: root.visible = false

        Column {
            anchors.fill: parent
            anchors.margins: root.theme.popupInsets.large
            spacing: root.theme.spacingTokens.md

            PopupHeader {
                theme: root.theme
                parentAnchored: false
                headerHeight: 30
                horizontalInset: 0
                topInset: 0
                leadingTablerIcon: "bar-printer"
                iconBoxSize: 28
                iconBoxRadius: root.theme.radiusSm
                iconBoxColor: root.theme.glassHoverSurface
                iconPixelSize: root.theme.iconTokens.lgPlus
                contentGap: root.theme.spacingTokens.smPlus
                actionSpacing: root.theme.spacingTokens.sm
                title: "Impressoras"
                titlePixelSize: root.theme.typeTokens.bodyEmphasis
                titleWeight: Font.Bold

                PopupIconButton {
                    width: 28
                    height: 28
                    radius: root.theme.radiusButton
                    theme: root.theme
                    tablerIcon: "bar-refresh"
                    iconPixelSize: root.theme.iconTokens.md
                    normalBackground: root.theme.glassCardSurface
                    hoverBackground: root.theme.glassHoverSurface
                    normalForeground: root.theme.primary
                    hoverForeground: root.theme.primary
                    onClicked: root.refreshRequested()
                }

                PopupSettingsButton {
                    width: 28
                    height: 28
                    radius: root.theme.radiusButton
                    theme: root.theme
                    normalBackground: root.theme.glassCardSurface
                    hoverBackground: root.theme.glassHoverSurface
                    normalForeground: root.theme.surfaceVariantForeground
                    hoverForeground: root.theme.foreground
                    iconPixelSize: root.theme.iconTokens.md
                    onClicked: root.settingsRequested()
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.borderSubtle
            }

            Repeater {
                model: root.printers

                delegate: PopupListRow {
                    id: printerDelegate
                    required property var modelData
                    theme: root.theme
                    rowHeight: 42
                    hoverEnabled: false
                    leadingTablerIcon: "bar-printer"
                    leadingIconColor: printerDelegate.modelData.state === "stopped" || printerDelegate.modelData.state === "unknown"
                        ? root.theme.red
                        : (printerDelegate.modelData.state === "printing"
                            ? root.theme.orange
                            : root.theme.primary)
                    leadingIconPixelSize: root.theme.iconTokens.lgPlus
                    title: String(printerDelegate.modelData.name ?? "Impressora")
                        + (printerDelegate.modelData.default ? " · padrão" : "")
                    subtitle: String(printerDelegate.modelData.state_text ?? "")
                    subtitleColor: printerDelegate.modelData.state === "stopped" || printerDelegate.modelData.state === "unknown"
                        ? root.theme.red
                        : root.theme.surfaceVariantForeground
                }
            }

            Text {
                visible: root.jobs.length > 0
                text: "Fila"
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.body
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: parent.width
                height: 30
                radius: root.theme.radiusSm
                color: queueHover.hovered ? root.theme.glassHoverSurface
                                          : root.theme.glassCardSurface
                border.width: 1
                border.color: root.theme.borderSubtle

                Text {
                    anchors.centerIn: parent
                    text: "Abrir fila no CUPS  ↗"
                    color: root.theme.primary
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.body
                    font.weight: Font.DemiBold
                }

                HoverHandler { id: queueHover }
                TapHandler { onTapped: root.queueRequested() }
            }

            Item {
                visible: root.jobs.length > 0
                width: parent.width
                height: Math.min(210, jobsColumn.implicitHeight)

                Flickable {
                    id: jobsFlick
                    anchors.fill: parent
                    clip: true
                    contentWidth: width
                    contentHeight: jobsColumn.implicitHeight

                    WheelKinetic {
                        scrollTarget: jobsFlick
                    }

                    Column {
                        id: jobsColumn
                        width: parent.width
                        spacing: root.theme.spacingTokens.tight

                        Repeater {
                            model: root.jobs

                            delegate: PopupListRow {
                                id: printJobDelegate
                                required property var modelData
                                theme: root.theme
                                rowHeight: 39
                                title: String(printJobDelegate.modelData.title ?? printJobDelegate.modelData.id ?? "")
                                titlePixelSize: root.theme.typeTokens.meta
                                subtitle: String(printJobDelegate.modelData.printer ?? "")
                                    + (printJobDelegate.modelData.owner ? " · " + printJobDelegate.modelData.owner : "")
                                    + (printJobDelegate.modelData.id ? " · " + printJobDelegate.modelData.id : "")
                                    + (String(printJobDelegate.modelData.rank ?? "") === "active" ? " · ● imprimindo" : "")
                                subtitleColor: String(printJobDelegate.modelData.rank ?? "") === "active" ? root.theme.orange : root.theme.surfaceVariantForeground
                                trailing: Rectangle {
                                    width: 58
                                    height: 23
                                    radius: root.theme.radiusSm
                                    color: root.theme.withAlpha(root.theme.red, 0.10)
                                    border.width: 1
                                    border.color: root.theme.withAlpha(root.theme.red, 0.24)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancelar"
                                        color: root.theme.red
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: root.theme.typeTokens.caption
                                        font.weight: Font.DemiBold
                                    }

                                    TapHandler {
                                        enabled: !root.busy
                                        onTapped: root.cancelRequested(String(printJobDelegate.modelData.id ?? ""))
                                    }
                                }

                            }
                        }
                    }
                }
            }

            Item {
                visible: root.jobs.length === 0
                width: parent.width
                height: 28

                Text {
                    anchors.centerIn: parent
                    text: "Fila vazia"
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.typeTokens.meta
                }
            }

            Text {
                visible: root.errorText.length > 0
                width: parent.width
                text: root.errorText
                color: root.theme.red
                font.family: root.theme.fontFamily
                font.pixelSize: root.theme.typeTokens.caption
                wrapMode: Text.Wrap
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }
}
