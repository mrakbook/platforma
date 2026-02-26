import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from main import _payload  # noqa: E402


class PayloadTests(unittest.TestCase):
    def test_health_payload(self):
        os.environ["SERVICE_NAME"] = "platforma-svc-test"
        self.assertEqual(_payload("/health"), {"status": "ok", "service": "platforma-svc-test"})

    def test_root_payload_contains_message_and_service(self):
        os.environ["SERVICE_NAME"] = "platforma-svc-test"
        os.environ["APP_MESSAGE"] = "hello"
        self.assertEqual(_payload("/"), {"message": "hello", "service": "platforma-svc-test"})


if __name__ == "__main__":
    unittest.main()
