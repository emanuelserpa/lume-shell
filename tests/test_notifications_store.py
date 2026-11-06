import shutil
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import notification_store


class NotificationStoreTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = Path(tempfile.mkdtemp(prefix="qs_notification_test_"))
        self.orig_base = notification_store.BASE_DIR
        self.orig_db = notification_store.DB_PATH
        self.orig_max_history = notification_store.MAX_HISTORY
        notification_store.BASE_DIR = self.temp_dir / "notifications"
        notification_store.DB_PATH = notification_store.BASE_DIR / "notifications.db"
        notification_store.MAX_HISTORY = 2000
        notification_store.init_db()

    def tearDown(self):
        notification_store.BASE_DIR = self.orig_base
        notification_store.DB_PATH = self.orig_db
        notification_store.MAX_HISTORY = self.orig_max_history
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    @staticmethod
    def notification(received_at, summary="Mensagem"):
        return {
            "receivedAt": received_at,
            "appName": "Elecwhat",
            "desktopEntry": "elecwhat",
            "appIcon": "elecwhat",
            "image": "",
            "summary": summary,
            "body": "Conteúdo da notificação",
            "urgency": 1,
            "hints": {"image-path": "/tmp/avatar.png"},
        }

    def test_records_and_loads_snapshot_in_newest_first_order(self):
        old, inserted_old = notification_store.record_notification(
            self.notification(1000, "Antiga"))
        new, inserted_new = notification_store.record_notification(
            self.notification(5000, "Nova"))

        self.assertTrue(inserted_old)
        self.assertTrue(inserted_new)
        items = notification_store.get_history(10)
        self.assertEqual([item["id"] for item in items], [new["id"], old["id"]])
        self.assertEqual(items[0]["appName"], "Elecwhat")
        self.assertEqual(items[0]["receivedAt"], 5000)
        self.assertEqual(items[0]["hints"]["image-path"], "/tmp/avatar.png")
        self.assertEqual(items[0]["actions"], [])
        self.assertTrue(items[0]["archived"])

    def test_deduplicates_same_notification_replayed_during_reload(self):
        first, inserted = notification_store.record_notification(self.notification(10000))
        replay, replay_inserted = notification_store.record_notification(
            self.notification(11000))

        self.assertTrue(inserted)
        self.assertFalse(replay_inserted)
        self.assertEqual(replay["id"], first["id"])
        self.assertEqual(len(notification_store.get_history()), 1)

        _, inserted_later = notification_store.record_notification(
            self.notification(13001))
        self.assertTrue(inserted_later)
        self.assertEqual(len(notification_store.get_history()), 2)

    def test_retains_only_most_recent_configured_limit(self):
        notification_store.MAX_HISTORY = 3
        for i in range(5):
            notification_store.record_notification(
                self.notification(20000 + i * 3000, f"Mensagem {i}"))

        items = notification_store.get_history(10)
        self.assertEqual(len(items), 3)
        self.assertEqual([item["summary"] for item in items], [
            "Mensagem 4", "Mensagem 3", "Mensagem 2"])

    def test_clear_removes_persisted_history(self):
        notification_store.record_notification(self.notification(30000))
        notification_store.clear_history()
        self.assertEqual(notification_store.get_history(), [])

    def test_delete_removes_only_matching_notification_from_history(self):
        older, _ = notification_store.record_notification(
            self.notification(40000, "Mesmo chat"))
        newer, _ = notification_store.record_notification(
            self.notification(50000, "Mesmo chat"))

        result = notification_store.handle_request({
            "op": "delete",
            "notification": self.notification(50000, "Mesmo chat"),
        })

        self.assertTrue(result["deleted"])
        self.assertEqual(result["id"], newer["id"])
        self.assertEqual([item["id"] for item in notification_store.get_history()],
                         [older["id"]])

    def test_delete_archived_notification_by_id(self):
        archived, _ = notification_store.record_notification(
            self.notification(60000, "Arquivada"))

        result = notification_store.handle_request({
            "op": "delete",
            "id": archived["id"],
        })

        self.assertTrue(result["deleted"])
        self.assertEqual(notification_store.get_history(), [])

    def test_ignores_battery_notifications_from_history(self):
        bat = self.notification(70000, "Bateria fraca")
        bat["appName"] = "Battery"
        item, inserted = notification_store.record_notification(bat)
        self.assertFalse(inserted)
        self.assertIsNone(item)
        self.assertEqual(notification_store.get_history(), [])



if __name__ == "__main__":
    unittest.main()
