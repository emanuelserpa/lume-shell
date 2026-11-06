import QtQuick
import qs.components

Item {
    id: root

    required property var theme
    // Use either the default-content mode or a virtualized model/delegate list.
    property var model: null
    property Component delegate: null
    property Component footer: null
    property Component searchFieldComponent: null
    property bool showScrollBar: false
    property bool reserveScrollBarSpace: true
    property bool clipContent: true
    property bool showEmptyState: false
    property bool empty: false
    property string emptyIcon: ""
    property string emptyTitle: ""
    property string emptySubtitle: ""
    property int contentSpacing: theme.spacingTokens.xs
    property int sectionSpacing: theme.spacingTokens.sm
    property color scrollBarThumbColor: theme.accent
    property real scrollBarIdleOpacity: 0.4
    property real scrollBarHoverOpacity: 0.9

    default property alias content: contentColumn.data
    property alias contentY: listView.contentY
    property alias flickable: listView
    readonly property bool searchVisible: searchFieldComponent !== null
    readonly property bool delegateMode: delegate !== null
    readonly property Flickable scrollTarget: delegateMode ? delegateList : listView
    readonly property var wheelController: delegateMode ? delegateWheelController : contentWheelController
    readonly property real contentHeight: scrollTarget.contentHeight
    readonly property real viewWidth: scrollTarget.width

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    Column {
        anchors.fill: parent
        spacing: root.searchVisible ? root.sectionSpacing : 0

        Loader {
            id: searchLoader
            active: root.searchVisible
            visible: active
            width: parent.width
            sourceComponent: root.searchFieldComponent
        }

        Item {
            id: listFrame
            width: parent.width
            height: Math.max(0, parent.height - (root.searchVisible ? searchLoader.height + parent.spacing : 0))

            Flickable {
                id: listView
                visible: !root.delegateMode
                anchors.fill: parent
                anchors.rightMargin: root.showScrollBar
                    && (root.reserveScrollBarSpace || scrollBar.visible) ? scrollBar.width : 0
                contentWidth: width
                contentHeight: contentColumn.implicitHeight
                clip: root.clipContent
                boundsBehavior: Flickable.StopAtBounds

                WheelKinetic {
                    id: contentWheelController
                    scrollTarget: listView
                }

                Column {
                    id: contentColumn
                    width: listView.width
                    spacing: root.contentSpacing
                }
            }

            ListView {
                id: delegateList
                visible: root.delegateMode
                anchors.fill: parent
                anchors.rightMargin: root.showScrollBar
                    && (root.reserveScrollBarSpace || scrollBar.visible) ? scrollBar.width : 0
                clip: root.clipContent
                boundsBehavior: Flickable.StopAtBounds
                spacing: root.contentSpacing
                model: root.delegateMode ? root.model : null
                delegate: root.delegate
                footer: root.footer

                displaced: Transition {
                    enabled: root.theme.qmlAnimationsEnabled
                    NumberAnimation {
                        properties: "x,y"
                        duration: root.theme.motionLayout
                        easing.type: root.theme.motionEasing
                    }
                }

                WheelKinetic {
                    id: delegateWheelController
                    scrollTarget: delegateList
                }
            }

            EmptyState {
                anchors.centerIn: listFrame
                visible: root.showEmptyState && root.empty
                theme: root.theme
                icon: root.emptyIcon
                title: root.emptyTitle
                subtitle: root.emptySubtitle
            }

            ScrollBar {
                id: scrollBar
                anchors.top: listFrame.top
                anchors.bottom: listFrame.bottom
                anchors.right: listFrame.right
                target: root.scrollTarget
                theme: root.theme
                wheelController: root.wheelController
                thumbColor: root.scrollBarThumbColor
                idleOpacity: root.scrollBarIdleOpacity
                hoverOpacity: root.scrollBarHoverOpacity
                enabled: root.showScrollBar
            }
        }
    }
}
