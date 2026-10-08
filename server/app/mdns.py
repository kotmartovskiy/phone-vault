from __future__ import annotations

import os
import socket
from dataclasses import dataclass

from zeroconf import ServiceInfo, Zeroconf

SERVICE_TYPE = "_phone-vault._tcp.local."
DEFAULT_PORT = 8766


def local_advertise_address() -> str:
    configured = os.environ.get("PHONE_VAULT_ADVERTISE_HOST", "").strip()
    if configured:
        return configured
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


@dataclass
class MdnsAdvertiser:
    server_id: str
    version: str
    port: int = DEFAULT_PORT
    host: str | None = None

    def __post_init__(self) -> None:
        self.host = self.host or local_advertise_address()
        self._zeroconf: Zeroconf | None = None
        self._info: ServiceInfo | None = None

    @property
    def service_name(self) -> str:
        return f"Phone Vault {self.server_id[:8]}.{SERVICE_TYPE}"

    def start(self) -> None:
        if self._zeroconf is not None:
            return
        address = socket.inet_aton(self.host)
        info = ServiceInfo(
            SERVICE_TYPE,
            self.service_name,
            addresses=[address],
            port=self.port,
            properties={
                b"server_id": self.server_id.encode("utf-8"),
                b"version": self.version.encode("utf-8"),
            },
        )
        zc = Zeroconf()
        zc.register_service(info)
        self._zeroconf = zc
        self._info = info

    def stop(self) -> None:
        zc = self._zeroconf
        info = self._info
        self._zeroconf = None
        self._info = None
        if zc is None:
            return
        try:
            if info is not None:
                zc.unregister_service(info)
        finally:
            zc.close()
