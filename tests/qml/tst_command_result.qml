import QtQuick
import QtTest
import "../../services/CommandResult.js" as CommandResult

TestCase {
    name: "CommandResult"

    function test_normalizesVersionedFlatEnvelope() {
        const result = CommandResult.decode('{"ok":true,"version":2,"status":"ready","count":3,"error":null}')
        verify(result.ok)
        compare(result.version, 2)
        compare(result.data.status, "ready")
        compare(result.data.count, 3)
        compare(result.error, null)
    }

    function test_unwrapsVersionedDataEnvelope() {
        const result = CommandResult.decode('{"ok":true,"version":1,"data":{"count":4},"error":null}')
        verify(result.ok)
        compare(result.data.count, 4)
        verify(result.data.data === undefined)
    }

    function test_normalizesFailureAndMalformedJson() {
        const failure = CommandResult.decode('{"ok":false,"version":1,"error":"offline"}')
        verify(!failure.ok)
        compare(failure.error, "offline")

        const malformed = CommandResult.decode("not json")
        verify(!malformed.ok)
        verify(malformed.error.length > 0)
        compare(Object.keys(malformed.data).length, 0)
    }

    function test_infersFailureFromLegacyErrorPayload() {
        const result = CommandResult.decode('{"version":1,"error":"backend unavailable"}')
        verify(!result.ok)
        compare(result.error, "backend unavailable")
    }
}
