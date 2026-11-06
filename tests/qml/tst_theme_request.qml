import QtQuick
import QtTest
import "../../services/ThemeRequest.js" as ThemeRequest

TestCase {
    name: "ThemeRequest"

    function test_latestSelectionSurvivesBusyProcess() {
        const state = ThemeRequest.create()
        ThemeRequest.request(state, "nord")
        compare(ThemeRequest.take(state), "nord")
        const runningRevision = state.revision
        ThemeRequest.request(state, "gruvbox")
        ThemeRequest.request(state, "dracula")
        verify(!ThemeRequest.isCurrent(state, runningRevision))
        compare(ThemeRequest.take(state), "dracula")
        verify(ThemeRequest.isCurrent(state, state.revision))
        compare(ThemeRequest.take(state), "")
    }

    function test_returnToSameThemeStillInvalidatesOldResponse() {
        const state = ThemeRequest.create()
        ThemeRequest.request(state, "nord")
        ThemeRequest.take(state)
        const oldRevision = state.revision
        ThemeRequest.request(state, "dracula")
        ThemeRequest.request(state, "nord")
        verify(!ThemeRequest.isCurrent(state, oldRevision))
        compare(ThemeRequest.take(state), "nord")
    }
}
