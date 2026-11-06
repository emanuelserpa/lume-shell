pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell.Services.Notifications
import qs.services

// shared-ui-guard: allow — shared notification composition for toast and history.
Column {
    id: root

    required property var theme
    required property var notification
    property bool compact: false
    property bool historyLayout: false
    property bool expanded: false
    property bool dismissible: false
    property bool dismissButtonAlwaysVisible: false
    signal activated()
    signal dismissRequested()

    readonly property bool isCritical: notification && notification.urgency === NotificationUrgency.Critical
    readonly property bool isBattery: NotificationState.isBattery(notification)
    readonly property bool isWhatsAppNotification: {
        const app = [notification?.appName, notification?.appIcon,
                     notification?.desktopEntry,
                     notification?.hints?.["desktop-entry"]]
            .join(" ").toLowerCase()
        return app.includes("whatsapp") || app.includes("zapzap")
    }
    readonly property bool canActivate: Boolean(NotificationState.primaryAction(notification)
        || notification?.desktopEntry || notification?.hints?.["desktop-entry"])
    readonly property string bodyImageSource: NotificationState.imageSource(notification)
    readonly property color batteryAccent: isBattery ? NotificationState.batteryColor(notification, theme) : theme.red
    readonly property string appIconSource: {
        const resolved = String(NotificationState.resolveIcon(notification) ?? "")
        return resolved === String(notification?.image ?? "") ? "" : resolved
    }
    readonly property bool hasBodyImage: {
        const image = root.bodyImageSource
        return image.length > 0 && !image.startsWith("image://icon/") && image !== notification?.appIcon
    }
    spacing: root.compact ? root.theme.spacingTokens.sm : root.theme.spacingTokens.md

    // Keep the image and text as one vertically centered block.
    Row {
        width: parent.width
        spacing: bodyImgContainer.visible ? root.theme.spacingTokens.md : 0

        HoverHandler {
            cursorShape: root.canActivate
                         ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: !closeButton.hovered
            onTapped: {
                if (NotificationState.invokePrimaryAction(root.notification))
                    root.activated()
            }
        }

        Rectangle {
            id: bodyImgContainer
            readonly property bool hasPrimaryImage: root.hasBodyImage && bodyImage.status === Image.Ready
            readonly property bool hasReadyAppIcon: bodyAppIcon.status === Image.Ready
            width: visible ? (root.compact ? 38 : 52) : 0
            height: root.compact ? 38 : 52
            radius: root.compact ? root.theme.radiusMd : root.theme.radiusLg
            // Let the app badge extend past the image corner.
            clip: false
            color: root.isBattery && !hasPrimaryImage
                   ? root.theme.withAlpha(root.batteryAccent, 0.14)
                   : (!hasPrimaryImage && hasReadyAppIcon ? root.theme.glassCardSurface : "transparent")
            border.width: root.isBattery && !hasPrimaryImage ? 1 : 0
            border.color: root.isBattery && !hasPrimaryImage
                          ? root.theme.withAlpha(root.batteryAccent, 0.28)
                          : "transparent"
            visible: root.historyLayout || hasPrimaryImage || hasReadyAppIcon || root.isBattery
            anchors.verticalCenter: parent.verticalCenter

            Image {
                id: bodyImage
                property var captureWindow: Window.window
                anchors.fill: parent
                // Notification payloads may be full-resolution screenshots.
                // Decode only enough pixels for this small leading image slot;
                // Avoid decoding full-size payloads and caching one-off thumbnails.
                sourceSize: Qt.size(128, 128)
                cache: false
                asynchronous: true
                source: root.hasBodyImage ? root.bodyImageSource : ""
                fillMode: Image.PreserveAspectCrop
                visible: false
                function captureWhenReady() {
                    if (captureWindow && captureWindow.visible && status === Image.Ready
                            && root.bodyImageSource.startsWith("image://qsimage/"))
                        NotificationState.archiveNotificationImage(root.notification, bodyImageMaskEffect)
                }
                onStatusChanged: captureWhenReady()
                onCaptureWindowChanged: captureWhenReady()
                Connections {
                    target: bodyImage.captureWindow
                    function onVisibleChanged() { bodyImage.captureWhenReady() }
                }
            }

            Rectangle {
                id: bodyImageMask
                anchors.fill: parent
                radius: root.isWhatsAppNotification ? width / 2 : bodyImgContainer.radius
                color: "white"
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                id: bodyImageMaskEffect
                anchors.fill: parent
                source: bodyImage
                visible: root.hasBodyImage && bodyImage.status === Image.Ready
                autoPaddingEnabled: false
                maskEnabled: true
                maskSource: bodyImageMask
            }

            Image {
                id: bodyAppIcon
                anchors.centerIn: parent
                width: root.compact ? 26 : 34
                height: width
                source: root.appIconSource
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: !bodyImgContainer.hasPrimaryImage
                          && status === Image.Ready
            }

            Item {
                id: appBadge
                width: root.compact ? 20 : 24
                height: width
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -6
                anchors.bottomMargin: -6
                visible: bodyImgContainer.hasPrimaryImage
                         && bodyAppIcon.status === Image.Ready

                Image {
                    anchors.centerIn: parent
                    width: parent.width - 3
                    height: width
                    source: root.appIconSource
                    sourceSize.width: 64
                    sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
            }

            Text {
                anchors.centerIn: parent
                visible: !bodyImgContainer.hasPrimaryImage
                         && !bodyImgContainer.hasReadyAppIcon
                text: root.isBattery
                      ? NotificationState.batteryIcon(root.notification)
                      : (root.isCritical ? "󰀦" : "󰂚")
                color: root.isBattery ? root.batteryAccent
                       : (root.isCritical ? root.theme.red : root.theme.blue)
                font.family: root.theme.nerdFontFamily
                font.pixelSize: root.theme.iconTokens.xxl
            }
        }

        Column {
            width: parent.width - (bodyImgContainer.visible ? (bodyImgContainer.width + root.theme.spacingTokens.md) : 0)
            spacing: root.compact ? root.theme.spacingTokens.tiny : root.theme.spacingTokens.tight

            Row {
                width: parent.width
                spacing: root.theme.spacingTokens.xs

                Text {
                    width: Math.max(0, parent.width - timestamp.width - parent.spacing
                                    - (root.dismissible ? closeButton.width + parent.spacing : 0))
                    text: NotificationState.formatText(root.notification?.summary)
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.compact ? root.theme.typeTokens.bodyEmphasis : root.theme.typeTokens.titleMedium
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: root.historyLayout || root.expanded ? 2 : 1
                    visible: text.length > 0
                }

                Text {
                    id: timestamp
                    width: root.historyLayout ? 30 : implicitWidth
                    horizontalAlignment: Text.AlignRight
                    text: NotificationState.getFormattedTime(
                        root.notification?.id, root.notification?.receivedAt)
                    color: root.theme.surfaceVariantForeground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.historyLayout ? root.theme.typeTokens.body
                                    : (root.compact ? root.theme.typeTokens.meta : root.theme.typeTokens.caption)
                    anchors.verticalCenter: parent.verticalCenter
                }

                CloseButton {
                    id: closeButton
                    theme: root.theme
                    width: 24
                    buttonSize: 24
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.dismissible
                    enabled: root.expanded || root.dismissButtonAlwaysVisible
                    opacity: root.expanded || root.dismissButtonAlwaysVisible ? 1 : 0
                    accessibleLabel: "Fechar notificação"
                    onClicked: root.dismissRequested()
                    Behavior on opacity {
                        enabled: root.theme.qmlAnimationsEnabled
                        NumberAnimation { duration: root.theme.motionFast; easing.type: root.theme.motionEasing }
                    }
                }
            }

            Text {
                width: parent.width
                text: NotificationState.formatText(root.notification?.body)
                color: root.theme.offWhite
                font.family: root.theme.fontFamily
                font.pixelSize: root.historyLayout ? root.theme.typeTokens.subtitle
                                : (root.compact ? root.theme.typeTokens.body : root.theme.typeTokens.bodyEmphasis)
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: root.expanded ? 6 : 2
                visible: text.length > 0
            }
        }
    }

    // Actions stay beneath the centered image-and-text block.
    Row {
        width: parent.width
        spacing: root.theme.spacingTokens.xs
        visible: root.notification && root.notification.actions && root.notification.actions.length > 0 && root.expanded

        Repeater {
            model: root.notification ? root.notification.actions : []

            delegate: NotificationActionButton {
                required property var modelData
                action: modelData
                theme: root.theme
                buttonHeight: 40
                horizontalPadding: root.theme.spacingTokens.xxl
                labelPixelSize: root.theme.typeTokens.bodyEmphasis
                onActivated: root.activated()
            }
        }
    }
}
