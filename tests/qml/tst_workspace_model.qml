import QtQuick
import QtTest
import "../../services/WorkspaceModel.js" as WorkspaceModel

TestCase {
    name: "WorkspaceModel"

    function test_filtersAndSortsProtocolWindowsets() {
        const hidden = { name: "2", shouldDisplay: false }
        const values = WorkspaceModel.numericWindowsets([
            { name: "3", shouldDisplay: true },
            { name: "1", shouldDisplay: true },
            { name: "10", shouldDisplay: true },
            { name: "overview", shouldDisplay: true },
            hidden
        ], 9)

        compare(values.length, 2)
        compare(values[0].name, "1")
        compare(values[1].name, "3")
    }

    function test_adjacentWindowsetWrapsAcrossAvailableSet() {
        const first = { name: "1" }
        const third = { name: "3" }
        const values = [first, third]

        compare(WorkspaceModel.adjacentWindowset(values, "3", 1), first)
        compare(WorkspaceModel.adjacentWindowset(values, "1", -1), third)
        compare(WorkspaceModel.adjacentWindowset(values, "2", 1), null)
    }

    function test_hyprlandOccupancyUsesSnapshotWhenToplevelWasNotTracked() {
        verify(WorkspaceModel.hasHyprlandWindows({
            lastIpcObject: { windows: 1 },
            toplevels: { values: [] }
        }))
        verify(WorkspaceModel.hasHyprlandWindows({
            lastIpcObject: { windows: 0 },
            toplevels: { values: [{}] }
        }))
        verify(!WorkspaceModel.hasHyprlandWindows({
            lastIpcObject: { windows: 0 },
            toplevels: { values: [] }
        }))
    }

    function test_numericWorkspaceNumberNormalizesBackendIds() {
        compare(WorkspaceModel.numericWorkspaceNumber({ id: "3" }, { hyprland: true, maximum: 10 }), 3)
        compare(WorkspaceModel.numericWorkspaceNumber({ name: "4" }, { protocol: true, maximum: 10 }), 4)
        compare(WorkspaceModel.numericWorkspaceNumber({ number: 5 }, { mango: true, maximum: 10 }), 5)
        compare(WorkspaceModel.numericWorkspaceNumber({ id: 6 }, { maximum: 10 }), 6)
        compare(WorkspaceModel.numericWorkspaceNumber({ id: "special" }, { hyprland: true, maximum: 10 }), 0)
        compare(WorkspaceModel.numericWorkspaceNumber({ name: "30" }, { protocol: true, maximum: 10 }), 0)
    }
}
