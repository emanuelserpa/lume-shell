pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../launcher" as Launcher

TestCase {
    id: testCase
    name: "SpotlightRanking"

    Component {
        id: rankingFactory
        Launcher.SpotlightRanking {}
    }

    function test_matchingAppsAndActionsPrecedeMatchingWindows() {
        const ranking = rankingFactory.createObject(testCase)
        const apps = [{id: "app:firefox", kind: "app", provider: "apps", title: "Firefox"}]
        const windows = [{id: "window:firefox", kind: "window", provider: "windows", title: "Firefox"}]
        const actions = [{id: "action:firefox", kind: "system", provider: "commands", title: "Firefox"}]

        const results = ranking.merge("firefox", apps, windows, actions)

        compare(results.length, 3)
        compare(results[0].kind, "app")
        compare(results[1].kind, "system")
        compare(results[2].kind, "window")
        ranking.destroy()
    }
}
