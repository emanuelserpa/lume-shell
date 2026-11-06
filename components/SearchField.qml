import QtQuick

TextInput {
    id: root

    required property var theme
    property string placeholderText: ""
    property color placeholderColor: theme.surfaceVariantForeground
    property bool placeholderWhileFocused: true
    property int debounceInterval: 0

    signal queryChanged(string query)

    onTextChanged: {
        if (root.debounceInterval > 0)
            debounce.restart()
        else
            root.queryChanged(root.text)
    }

    Timer {
        id: debounce
        interval: root.debounceInterval
        repeat: false
        onTriggered: root.queryChanged(root.text)
    }

    Text {
        anchors.fill: parent
        visible: root.placeholderText.length > 0
                 && root.text.length === 0
                 && (root.placeholderWhileFocused || !root.activeFocus)
        text: root.placeholderText
        color: root.placeholderColor
        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        font.weight: root.font.weight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
