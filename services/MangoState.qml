pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "CompositorBackend.js" as CompositorBackend
import "MangoWorkspace.js" as MangoWorkspace

Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property bool mangoSession:
        CompositorBackend.kindForDesktop(Quickshell.env("XDG_CURRENT_DESKTOP") ?? "") === "mango"
    readonly property string instanceSignature: Quickshell.env("MANGO_INSTANCE_SIGNATURE") ?? ""
    readonly property bool available: root.mangoSession && root.instanceSignature.length > 0
    property var snapshot: ({ version: 1, provider: "mango-mmsg", outputs: ({}), focusedOutput: "" })

    readonly property var outputs: root.snapshot.outputs
    readonly property string focusedOutput: root.snapshot.focusedOutput

    function visibleTags(outputName) {
        return MangoWorkspace.visibleTags(root.outputs[String(outputName ?? "")])
    }

    function tagsForOutput(outputName) {
        const output = root.outputs[String(outputName ?? "")]
        return output && Array.isArray(output.tags) ? output.tags : []
    }

    function dispatchWorkspace(number, outputName) {
        const tag = Number(number)
        const output = String(outputName ?? "")
        if (!root.available || !Number.isInteger(tag) || tag < 1 || tag > 9 || !output)
            return false

        Quickshell.execDetached([
            Quickshell.shellDir + "/scripts/compositor-dispatch.sh",
            "workspace",
            String(tag),
            output
        ])
        return true
    }

    Process {
        id: tagsStream
        // all-monitors includes the focused-output flag as well as tags.
        // This keeps workspace pills and monitor-targeted OSDs in sync.
        command: ["mmsg", "watch", "all-monitors"]
        running: root.available

        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const normalized = MangoWorkspace.normalizeSnapshot(JSON.parse(line))
                    if (normalized)
                        root.snapshot = normalized
                } catch (error) {
                    console.warn("Mango workspace snapshot could not be parsed:", error)
                }
            }
        }
    }
}
