import QtQuick
import qs.components

Rectangle {
    id: root

    required property var theme
    property string icon: ""
    property string tablerIcon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool available: true
    property color accent: theme.accent
    property bool hasDetail: false

    signal clicked()
    signal detailClicked()

    implicitHeight: root.theme.softControlHeight
    radius: root.theme.radiusXl
    color: root.active
           ? root.theme.adaptiveCardActiveSurface
           : (iconHover.hovered || detailHover.hovered || wholeHover.hovered
              ? root.theme.adaptiveCardHoverSurface
              : root.theme.adaptiveCardSurface)
    border.width: 1
    border.color: root.active
                  ? root.theme.withAlpha(root.accent, 0.45)
                  : ((iconHover.hovered || detailHover.hovered || wholeHover.hovered)
                     ? root.theme.pillBorderHover
                     : root.theme.adaptiveCardBorder)
    opacity: root.available ? 1.0 : 0.48

    Behavior on color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }
    Behavior on border.color {
        enabled: root.theme.qmlAnimationsEnabled
        ColorAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
    }
    Behavior on opacity {
        enabled: root.theme.qmlAnimationsEnabled
        NumberAnimation { duration: root.theme.motionStandard; easing.type: root.theme.motionEasing }
    }

    // Background state layer for non-detail tiles
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: !root.hasDetail
        color: root.theme.stateLayer(
            root.theme.surfaceForeground,
            wholeTap.pressed ? "pressed" : wholeHover.hovered ? "hover" : "none"
        )
    }

    Row {
        anchors.fill: parent
        anchors.margins: root.theme.spacingTokens.sm
        spacing: root.theme.spacingTokens.sm

        // Icon Box (toggles when clicked)
        Rectangle {
            id: iconBox
            width: 32
            height: 32
            radius: root.theme.radiusLg
            anchors.verticalCenter: parent.verticalCenter
            color: root.active
                   ? root.theme.withAlpha(root.accent, 0.22)
                   : root.theme.withAlpha(root.theme.surfaceContainerHighest, root.theme.isLight ? 0.48 : 0.34)

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: root.hasDetail
                color: root.theme.stateLayer(
                    root.theme.surfaceForeground,
                    iconTap.pressed ? "pressed" : iconHover.hovered ? "hover" : "none"
                )
            }

            Text {
                visible: root.tablerIcon.length === 0
                anchors.centerIn: parent
                text: root.icon
                color: root.active ? root.accent : (root.theme.isLight ? root.theme.foreground : root.theme.offWhite)
                font.family: root.theme.nerdFontFamily
                font.pixelSize: root.theme.iconTokens.xl
            }

            TablerIcon {
                visible: root.tablerIcon.length > 0
                anchors.centerIn: parent
                width: root.theme.iconTokens.lgPlus
                height: root.theme.iconTokens.lgPlus
                iconName: root.tablerIcon
                iconColor: root.active ? root.accent : (root.theme.isLight ? root.theme.foreground : root.theme.offWhite)
            }

            HoverHandler {
                id: iconHover
                enabled: root.hasDetail
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: iconTap
                enabled: root.available && root.hasDetail
                onTapped: root.clicked()
            }
        }

        // Content Area (Title, Subtitle, and optional Chevron)
        Item {
            id: contentArea
            width: parent.width - iconBox.width - parent.spacing
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: root.theme.radiusMd
                visible: root.hasDetail
                color: root.theme.stateLayer(
                    root.theme.surfaceForeground,
                    detailTap.pressed ? "pressed" : detailHover.hovered ? "hover" : "none"
                )
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: root.theme.spacingTokens.tiny
                anchors.right: chevronText.visible ? chevronText.left : parent.right
                anchors.rightMargin: root.theme.spacingTokens.xs
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.theme.spacingTokens.micro

                Text {
                    width: parent.width
                    text: root.title
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.dashboardTitleFontSize
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.subtitle
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.dashboardMetaFontSize
                    elide: Text.ElideRight
                }
            }

            TablerIcon {
                id: chevronText
                visible: root.hasDetail
                anchors.right: parent.right
                anchors.rightMargin: root.theme.spacingTokens.xsPlus
                anchors.verticalCenter: parent.verticalCenter
                width: root.theme.iconTokens.md
                height: root.theme.iconTokens.md
                iconName: "dashboard-chevron-right"
                iconColor: detailHover.hovered ? root.theme.foreground : root.theme.surfaceVariantForeground
            }

            HoverHandler {
                id: detailHover
                enabled: root.hasDetail
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: detailTap
                enabled: root.available && root.hasDetail
                onTapped: root.detailClicked()
            }
        }
    }

    // Handlers for whole-tile clicks when hasDetail is false
    HoverHandler {
        id: wholeHover
        enabled: !root.hasDetail
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: wholeTap
        enabled: root.available && !root.hasDetail
        onTapped: root.clicked()
    }
}
