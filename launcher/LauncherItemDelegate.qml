import QtQuick
import Quickshell
import Quickshell.Widgets
import "AppIconResolver.js" as AppIconResolver

Item {
    id: resultRow

    required property var modelData
    required property int index
    property int currentIndex: -1
    required property var themeColors
    property bool showProvider: false

    property color launcherForeground: themeColors.surfaceForeground
    property color launcherSecondary: themeColors.surfaceVariantForeground
    property color launcherMuted: themeColors.surfaceVariantForeground

    signal activated(int index)

    readonly property var resultPayload: resultRow.modelData.payload ?? ({})

    readonly property bool imageClipboard:
        modelData.kind === "clipboard"
        && String(resultPayload.thumbnail ?? "").length > 0

    // Selected (non-clipboard) rows expand to show full wrapped text
    // instead of truncating; clipboard already has the preview pane.
    readonly property bool expanded: resultRow.currentIndex === resultRow.index
        && String(modelData.kind ?? "") !== "clipboard"
        && !resultRow.imageClipboard

    width: ListView.view ? ListView.view.width : (parent ? parent.width : 0)
    height: imageClipboard ? 66 : (resultRow.expanded ? Math.min(120, textCol.implicitHeight + 16) : 47)

    TapHandler {
        onTapped: resultRow.activated(resultRow.index)
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: resultRow.themeColors.spacingTokens.lgPlus
        anchors.rightMargin: resultRow.themeColors.spacingTokens.lgPlus
        spacing: resultRow.themeColors.spacingTokens.mdPlus

        Rectangle {
            id: leadingPreview
            width: resultRow.imageClipboard ? 96 : 36
            height: resultRow.imageClipboard ? 56 : 36
            anchors.verticalCenter: parent.verticalCenter
            radius: resultRow.imageClipboard ? 8 : 10

            color: resultRow.themeColors.glassCardSurface
            border.width: 1
            border.color: resultRow.themeColors.borderSubtle
            clip: true

            Image {
                id: thumbPreview
                anchors.fill: parent
                anchors.margins: resultRow.imageClipboard ? 2 : 3
                visible: resultRow.imageClipboard
                source: visible ? String(resultRow.resultPayload.thumbnail) : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
                sourceSize.width: 192
                sourceSize.height: 112
            }

            IconImage {
                id: rowIconImage
                anchors.centerIn: parent
                width: resultRow.themeColors.spotlightIconTokens.result
                height: resultRow.themeColors.spotlightIconTokens.result
                visible: !thumbPreview.visible && source.toString().length > 0
                source: (resultRow.modelData.kind === "app" || resultRow.modelData.kind === "window")
                        && String(resultRow.resultPayload.icon ?? "").length > 0
                        ? AppIconResolver.resolve(
                              resultRow.resultPayload.icon,
                              Quickshell.iconPath(resultRow.resultPayload.icon, true))
                        : ""
            }

            Text {
                anchors.centerIn: parent
                visible: !thumbPreview.visible && !rowIconImage.visible
                text: resultRow.modelData.kind === "window"
                      ? "󰖯"
                      : String(resultRow.resultPayload.icon ?? "")
                color: resultRow.resultPayload.color
                       ? resultRow.resultPayload.color
                       : ((resultRow.modelData.kind === "kill" || resultRow.modelData.kind === "close_window")
                          ? resultRow.themeColors.error
                          : (resultRow.currentIndex === resultRow.index
                             ? resultRow.themeColors.primary
                             : resultRow.themeColors.surfaceVariantForeground))
                font.family: resultRow.modelData.kind === "emoji"
                             ? resultRow.themeColors.fontFamily
                             : resultRow.themeColors.nerdFontFamily
                font.pixelSize: resultRow.themeColors.spotlightIconTokens.result
            }
        }

        Column {
            id: textCol
            width: parent.width - leadingPreview.width - 67
            anchors.verticalCenter: parent.verticalCenter
            spacing: resultRow.themeColors.spacingTokens.tiny

            Text {
                width: parent.width
                text: String(resultRow.modelData.title ?? "")
                textFormat: Text.PlainText
                color: resultRow.currentIndex === resultRow.index
                       ? ((resultRow.modelData.kind === "kill" || resultRow.modelData.kind === "close_window")
                          ? resultRow.themeColors.errorContainerForeground
                          : resultRow.themeColors.primaryContainerForeground)
                       : resultRow.launcherForeground
                opacity: 1.0
                font.family: resultRow.themeColors.fontFamily
                font.pixelSize: resultRow.themeColors.spotlightTitleFontSize
                font.weight: Font.DemiBold
                wrapMode: resultRow.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: resultRow.expanded ? 4 : 1
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: {
                    const section = resultRow.showProvider
                            ? String(resultRow.modelData.section ?? "") : ""
                    const subtitle = String(resultRow.modelData.subtitle ?? "")
                    return section.length > 0 && subtitle.length > 0
                            ? section + " · " + subtitle
                            : (section.length > 0 ? section : subtitle)
                }
                textFormat: Text.PlainText
                color: resultRow.currentIndex === resultRow.index
                       ? ((resultRow.modelData.kind === "kill" || resultRow.modelData.kind === "close_window")
                          ? resultRow.themeColors.errorContainerForeground
                          : resultRow.themeColors.primaryContainerForeground)
                       : resultRow.launcherSecondary
                font.family: resultRow.themeColors.fontFamily
                font.pixelSize: resultRow.themeColors.spotlightBodyFontSize
                wrapMode: resultRow.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: resultRow.expanded ? 3 : 1
                elide: Text.ElideRight
            }
        }

        Text {
            width: 42
            anchors.verticalCenter: parent.verticalCenter

            text: resultRow.currentIndex === resultRow.index
                  ? "↵"
                  : ""

            color: resultRow.launcherMuted
            font.family: resultRow.themeColors.fontFamily
            font.pixelSize: resultRow.themeColors.spotlightHintFontSize
            horizontalAlignment: Text.AlignRight
        }
    }
}
