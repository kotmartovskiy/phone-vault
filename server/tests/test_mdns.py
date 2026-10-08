import socket

from app.mdns import MdnsAdvertiser, SERVICE_TYPE


def test_mdns_service_metadata():
    advertiser = MdnsAdvertiser("server-123", "0.2.0", port=8766, host="192.168.3.236")
    assert SERVICE_TYPE == "_phone-vault._tcp.local."
    assert advertiser.service_name.startswith("Phone Vault server-1")
    assert advertiser.host == "192.168.3.236"


def test_mdns_start_stop(monkeypatch):
    class FakeZeroconf:
        def __init__(self):
            self.registered = None
            self.unregistered = None
            self.closed = False
        def register_service(self, info): self.registered = info
        def unregister_service(self, info): self.unregistered = info
        def close(self): self.closed = True

    fake = FakeZeroconf()
    monkeypatch.setattr("app.mdns.Zeroconf", lambda: fake)
    advertiser = MdnsAdvertiser("server-123", "0.2.0", port=8766, host="192.168.3.236")
    advertiser.start()
    assert fake.registered is not None
    assert fake.registered.port == 8766
    advertiser.stop()
    assert fake.unregistered is not None
    assert fake.closed
