pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../launcher" as Launcher
import "../../launcher/SpotlightActionLogic.js" as ActionLogic

TestCase {
    id: testCase
    name: "SpotlightActionLogic"

    readonly property var groupOrder: ["Principal", "Copiar", "Ações", "Gerenciar"]
    readonly property var appActions: [
        {id: "open", title: "Abrir", group: "Principal"},
        {id: "open-new", title: "Nova instância", group: "Ações"},
        {id: "copy-command", title: "Copiar comando", group: "Copiar"}
    ]
    property var searchLogic
    property var actionCatalog
    property var resultNormalizer

    Component {
        id: searchFactory
        Launcher.SpotlightSearch {}
    }

    Component {
        id: actionCatalogFactory
        Launcher.SpotlightActionCatalog {}
    }

    Component {
        id: resultNormalizerFactory
        Launcher.SpotlightResult {}
    }

    function init() {
        searchLogic = searchFactory.createObject(testCase)
        actionCatalog = actionCatalogFactory.createObject(testCase)
        resultNormalizer = resultNormalizerFactory.createObject(testCase)
    }

    function cleanup() {
        searchLogic.destroy()
        searchLogic = null
        actionCatalog.destroy()
        actionCatalog = null
        resultNormalizer.destroy()
        resultNormalizer = null
    }

    function test_groupingMatchesVisibleActionOrder() {
        const entries = ActionLogic.groupedActions(appActions, groupOrder, "")

        compare(entries.length, 3)
        compare(ActionLogic.actionAt(entries, 0).id, "open")
        compare(ActionLogic.actionAt(entries, 1).id, "copy-command")
        compare(ActionLogic.actionAt(entries, 2).id, "open-new")
    }

    function test_filterAndSelectionUseSameEntries() {
        const entries = ActionLogic.groupedActions(appActions, groupOrder, "copiar")

        compare(entries.length, 1)
        compare(ActionLogic.actionAt(entries, 0).id, "copy-command")
        compare(ActionLogic.moveIndex(entries, 0, 1), 0)
    }

    function test_navigationWrapsOverVisibleEntries() {
        const entries = ActionLogic.groupedActions(appActions, groupOrder, "")

        compare(ActionLogic.moveIndex(entries, 2, 1), 0)
        compare(ActionLogic.moveIndex(entries, 0, -1), 2)
        compare(ActionLogic.moveIndex([], 0, 1), 0)
    }

    function test_copyExpressionReturnsOriginalExpression() {
        const result = searchLogic.calcResult("125 * 1.18")[0]

        compare(result.expression, "125 * 1.18")
        compare(ActionLogic.clipboardValue("copy-expression", {
            kind: "calc", value: result.value, expression: result.expression
        }), "125 * 1.18")
    }

    function test_unknownOrMissingClipboardValueIsRejected() {
        compare(ActionLogic.clipboardValue("copy-expression", {value: "42"}), null)
        compare(ActionLogic.clipboardValue("unknown", {value: "42"}), null)
    }

    function test_everyCatalogActionHasAResolvedOperation() {
        const fixtures = [
            {kind: "app", entry: {execString: "browser", execute: function() {}}},
            {kind: "file", path: "/tmp/report.txt"},
            {kind: "window", address: "abc123", handle: {activate: function() {}, close: function() {}}},
            {kind: "clipboard", clipId: "7", clipSignature: "sig"},
            {kind: "emoji", emoji: "🔥"},
            {kind: "calc", value: "147.5", expression: "125 * 1.18"},
            {kind: "command", command: "date"}
        ]

        for (const item of fixtures) {
            const actions = actionCatalog.actionsFor(item)
            for (const action of actions) {
                const operation = ActionLogic.resolveCatalogAction(
                    action.id, item, action.primary, true, "/home/test")
                verify(operation !== null, item.kind + "/" + action.id + " must be executable")
            }
        }
    }

    function test_imageClipboardKeepsEnterRestoreAndAddsOpenImageSecondaryAction() {
        const item = {
            kind: "clipboard",
            clipId: "17",
            clipSignature: "image-hash",
            clipType: "image"
        }
        const actions = actionCatalog.actionsFor(item)

        compare(actions.length, 2)
        compare(actions[0].id, "restore")
        compare(actions[0].primary, true)
        compare(actions[1].id, "open-image")
        compare(actions[1].title, "Abrir imagem")
        compare(actions[1].hint, "Ctrl+Enter")

        const primaryOperation = ActionLogic.resolveCatalogAction(
            actions[0].id, item, actions[0].primary, true, "/home/test")
        compare(primaryOperation.type, "activate")

        const secondaryOperation = ActionLogic.resolveCatalogAction(
            actions[1].id, item, actions[1].primary, true, "/home/test")
        compare(secondaryOperation.type, "open-clipboard-image")
    }

    function test_linkClipboardKeepsEnterRestoreAndOffersVideoAndAudioDownloads() {
        const item = {
            kind: "clipboard",
            clipId: "23",
            clipSignature: "link-hash",
            clipType: "text",
            clipboardUrl: "https://example.com/watch?v=123"
        }
        const actions = actionCatalog.actionsFor(item)

        compare(actions.length, 4)
        compare(actions[0].id, "restore")
        compare(actions[0].primary, true)
        compare(actions[1].id, "copy")
        compare(actions[1].hint, "Ctrl+Enter")
        compare(actions[2].id, "download-video")
        compare(actions[3].id, "download-audio")
        compare(ActionLogic.resolveCatalogAction(
            actions[0].id, item, true, true, "/home/test").type, "activate")
        compare(ActionLogic.resolveCatalogAction(
            actions[1].id, item, false, true, "/home/test").type, "restore-clipboard")
        const video = ActionLogic.resolveCatalogAction(
            actions[2].id, item, false, true, "/home/test")
        compare(video.type, "open-download-panel")
        compare(video.url, item.clipboardUrl)
        compare(video.mode, "video")
        const audio = ActionLogic.resolveCatalogAction(
            actions[3].id, item, false, true, "/home/test")
        compare(audio.type, "open-download-panel")
        compare(audio.mode, "audio")
    }

    function test_nonUrlClipboardDoesNotOfferDownloadActions() {
        const item = {kind: "clipboard", clipType: "text", fullText: "https://example.com and more text"}
        const actions = actionCatalog.actionsFor(item)
        compare(actions.some(action => action.id === "download-video"), false)
        compare(actions.some(action => action.id === "download-audio"), false)
    }

    function test_normalizedPayloadCarriesActionData() {
        const entry = {execString: "browser", execute: function() {}}
        const result = resultNormalizer.normalize({
            kind: "app", title: "Browser", entry: entry
        }, "apps", actionCatalog)

        compare(result.payload.kind, "app")
        compare(result.payload.title, "Browser")
        compare(result.payload.entry, entry)
        compare(result.primaryAction, "open")
        compare(result.actions.includes("open-new"), true)
    }

    function test_normalizedCalcPayloadResolvesCopyExpression() {
        const result = resultNormalizer.normalize({
            kind: "calc", value: "147.5", expression: "125 * 1.18"
        }, "calc", actionCatalog)
        const operation = ActionLogic.resolveCatalogAction(
            "copy-expression", result, false, true, "/home/test")

        compare(operation.type, "copy")
        compare(operation.value, "125 * 1.18")
    }

    function test_normalizedClipboardPayloadCarriesPreviewFields() {
        const result = resultNormalizer.normalize({
            kind: "clipboard",
            clipId: "17",
            clipSignature: "hash",
            clipType: "image",
            icon: "image-icon",
            thumbnail: "file:///tmp/thumb.png",
            mime: "image/png",
            fullText: "clipboard contents",
            lineCount: 2,
            charCount: 34
        }, "clipboard", actionCatalog)

        compare(result.payload.clipId, "17")
        compare(result.payload.clipSignature, "hash")
        compare(result.payload.clipType, "image")
        compare(result.payload.thumbnail, "file:///tmp/thumb.png")
        compare(result.payload.mime, "image/png")
        compare(result.payload.fullText, "clipboard contents")
        compare(result.payload.lineCount, 2)
        compare(result.payload.charCount, 34)
    }
}
