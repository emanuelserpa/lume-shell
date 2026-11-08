import QtQuick
import QtTest
import "../../services/NotificationStoreQueue.js" as StoreQueue

TestCase {
    name: "NotificationStoreQueue"

    function test_appendOverflowKeepsNewestRequestsWithinLimit() {
        const first = {op: "append", id: 1}
        const second = {op: "append", id: 2}
        const third = {op: "append", id: 3}
        const result = StoreQueue.enqueue([first, second, third],
                                          {op: "append", id: 4}, 3)

        compare(result.queue.length, 3)
        compare(result.queue[0].id, 2)
        compare(result.queue[2].id, 4)
        compare(result.dropped, 1)
        verify(!result.rejected)
    }

    function test_controlRequestEvictsOldestAppendFirst() {
        const result = StoreQueue.enqueue([
            {op: "append", id: 1},
            {op: "delete", id: "archive-2"},
            {op: "append", id: 3}
        ], {op: "delete", id: "archive-4"}, 3)

        compare(result.queue.length, 3)
        compare(result.queue[0].op, "delete")
        compare(result.queue[0].id, "archive-2")
        compare(result.queue[2].id, "archive-4")
        compare(result.dropped, 1)
        verify(!result.rejected)
    }

    function test_overflowOfControlsIsExplicitlyRejected() {
        const queue = [
            {op: "delete", id: "one"},
            {op: "delete", id: "two"}
        ]
        const result = StoreQueue.enqueue(queue, {op: "delete", id: "three"}, 2)

        compare(result.queue.length, 2)
        compare(result.dropped, 1)
        verify(result.rejected)
    }

    function test_clearSupersedesQueuedOperations() {
        const result = StoreQueue.enqueue([
            {op: "append", id: 1},
            {op: "delete", id: "archive-2"}
        ], {op: "clear"}, 2)

        compare(result.queue.length, 1)
        compare(result.queue[0].op, "clear")
        compare(result.dropped, 0)
        verify(!result.rejected)
    }

    function test_retryDelayDoublesAndCapsAtOneMinute() {
        compare(StoreQueue.retryDelay(1, 60000), 1000)
        compare(StoreQueue.retryDelay(2, 60000), 2000)
        compare(StoreQueue.retryDelay(3, 60000), 4000)
        compare(StoreQueue.retryDelay(8, 60000), 60000)
        compare(StoreQueue.retryDelay(9, 60000), 60000)
    }
}
